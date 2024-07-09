class ScrollableGui ;  ahk2.0
{
    static init()    {
        this.registerWndProc(-1,-1)
    }
    static _coord:=map(), _hRootWnd:=0
    ;--------------------------------------------------
    static register(hWnd)    {
        static SIF_DISABLENOSCROLL  := 0x0008
            ,SIF_PAGE               := 0x0002
            ,SIF_POS                := 0x0004
            ,SIF_RANGE              := 0x0001
            ,SB_HORZ    := 0
            ,SB_VERT    := 1

            ,WS_HSCROLL := 0x00100000
            ,WS_VSCROLL := 0x00200000

        if (!dllCall("User32.dll\IsWindow", "Ptr",hWnd:=integer(hWnd)))
            return false
        if (!this._coord.has(hWnd))    {
            this._coord[hWnd]:={border:{left:0,top:0,right:0,bottom:0}
                ,invisibility:{hscroll:true,vscroll:true}}
        }
        lpRect:=buffer(16,0)
        ,dllCall("User32.dll\GetClientRect", "Ptr",hWnd, "Ptr",lpRect.Ptr)
        ,client:={}
        ,client.left    := numGet(lpRect,0,"Int")
        ,client.top     := numGet(lpRect,4,"Int")
        ,client.right   := numGet(lpRect,8,"Int")
        ,client.bottom  := numGet(lpRect,12,"Int")
        ,style:=this._getWindowStyle(hWnd)
        if (this._coord[hWnd].invisibility.hscroll:=!(style&WS_HSCROLL))    {
            if (this._getVScrollBarInfo(hWnd, &objsbi))
                client.right+=objsbi.rcScrollBar.right-objsbi.rcScrollBar.left ;  vscrollBarWidth
        }
        if (this._coord[hWnd].invisibility.vscroll:=!(style&WS_VSCROLL))    {
            if (this._getHScrollBarInfo(hWnd, &objsbi))
                client.bottom+=objsbi.rcScrollBar.bottom-objsbi.rcScrollBar.top ;  hscrollBarHeight
        }
        for k,v in this._coord[hWnd].border.ownProps()
            this._coord[hWnd].border.%k%:=client.%k%
        border:=this._coord[hWnd].border
        ,invisibility:=this._coord[hWnd].invisibility
        ;-----------------------------------
        ,lpsi:=buffer(28,0)
        ,numPut("UInt",28,lpsi,0), numPut("UInt",SIF_PAGE|SIF_POS|SIF_RANGE,lpsi,4)
        ,width:=border.right-border.left
        ,numPut("Int",0,lpsi,8)         ;  nMin
        ,numPut("Int",width-invisibility.vscroll,lpsi,12)  ;  nMax
        ,numPut("UInt",width,lpsi,16)   ;  The nPage member must specify a value from 0 to nMax - nMin +1
        ,dllCall("User32.dll\SetScrollInfo", "Ptr",hWnd, "Int",SB_HORZ, "Ptr",lpsi.Ptr, "Int",true, "Int")
        ;-----------------------------------
        ,lpsi:=buffer(28,0)
        ,numPut("UInt",28,lpsi,0), numPut("UInt",SIF_PAGE|SIF_POS|SIF_RANGE,lpsi,4)
        ,height:=border.bottom-border.top      
        ,numPut("Int",0,lpsi,8)         ;  nMin
        ,numPut("Int",height-invisibility.hscroll,lpsi,12) ;  nMax
        ,numPut("UInt",height,lpsi,16)  ;  nPage
        ,dllCall("User32.dll\SetScrollInfo", "Ptr",hWnd, "Int",SB_VERT, "Ptr",lpsi.Ptr, "Int",true, "Int")
        return true
    }
    static unregister(hWnd)    {
        if (this._coord.has(hWnd:=integer(hWnd)))
            return (this._coord.delete(hWnd), true)
        return false
    }
    static isRegistered(hWnd)    {
        return (this._coord.has(hWnd:=integer(hWnd)))
    }
    /*
    static setOptions(hWnd, option?)    { ;  Not implemented yet.
    }
    */
    ;--------------------------------------------------
    static registerWndProc(Msg:=-1, maxThreads:=-1)    {
        static WM_DESTROY:=0x0002,WM_HSCROLL:=0x0114, WM_VSCROLL:=0x0115, WM_LBUTTONDOWN:=0x0201, WM_MOUSEWHEEL:=0x020A, WM_MOUSEHWHEEL:=0x020E, WM_SIZING:=0x0214, WM_EXITSIZEMOVE:=0x0232
        if (!this.hasProp("_obmWndProc"))
            this._objbmWndProc:=objBindMethod(this,"wndProc")
        objbm:=this._objbmWndProc
        if (Msg!==-1)    {
            onMessage(Msg,objbm,maxThreads)
        }  else  {
            for _,Msg in [WM_DESTROY,WM_HSCROLL,WM_VSCROLL,WM_LBUTTONDOWN,WM_MOUSEWHEEL,WM_MOUSEHWHEEL,WM_SIZING,WM_EXITSIZEMOVE]
                onMessage(Msg,objbm,maxThreads)
        }
    }
    static wndProc(wParam, lParam, Msg, hWnd)    { ;  UPtr  Ptr  UInt  Ptr
        static GA_ROOT:=2
            ,WM_DESTROY:=0x0002,WM_HSCROLL:=0x0114, WM_VSCROLL:=0x0115, WM_LBUTTONDOWN:=0x0201, WM_MOUSEWHEEL:=0x020A, WM_MOUSEHWHEEL:=0x020E, WM_SIZING:=0x0214, WM_EXITSIZEMOVE:=0x0232
        if (Msg==WM_DESTROY)    {
            this.unregister(hWnd)
            return
        }
        prevIC := critical("On")
        ret:=""
        if (this.isRegistered(this._hRootWnd:=dllCall("User32.dll\GetAncestor", "Ptr",hWnd, "UInt",GA_ROOT, "Ptr")))    {
            switch (Msg)
            {
                case WM_DESTROY:
                case WM_HSCROLL,WM_VSCROLL:         ret:=this._onScroll(wParam, lParam, Msg, hWnd)
                case WM_LBUTTONDOWN:
                    if (this._hRootWnd==hWnd)
                        dllCall("User32.dll\SetFocus", "Ptr",0, "Ptr")
                case WM_MOUSEWHEEL,WM_MOUSEHWHEEL:  ret:=this._onMouseWheel(wParam, lParam, Msg, hWnd)
                case WM_SIZING:                     ret:=this._onSizing(wParam, lParam, Msg, hWnd)
                case WM_EXITSIZEMOVE:               ret:=this._onExitSizeMove(wParam, lParam, Msg, hWnd)
            }
        }
        critical(prevIC)
        return ret
    }
    ;--------------------------------------------------
    static CXVSCROLL    {
        get  {
            static SM_CXVSCROLL:=2
            return this._getSystemMetrics(SM_CXVSCROLL)
        }
    }
    static CYHSCROLL    {
        get  {
            static SM_CYHSCROLL:=3
            return this._getSystemMetrics(SM_CYHSCROLL)
        }
    }
    ;--------------------------------------------------
    static _onScroll(wParam, _, Msg, hWnd)    {
        static WM_HSCROLL       := 0x0114
            ,WM_VSCROLL         := 0x0115

            ,SB_CTL             := 2
            ,SB_HORZ            := 0
            ,SB_VERT            := 1

            ,SIF_ALL            := 0x0017 ;  (SIF_RANGE | SIF_PAGE | SIF_POS | SIF_TRACKPOS)
            ,SIF_DISABLENOSCROLL:= 0x0008
            ,SIF_PAGE           := 0x0002
            ,SIF_POS            := 0x0004
            ,SIF_RANGE          := 0x0001
            ,SIF_TRACKPOS       := 0x0010

            ,SB_ENDSCROLL       := 8 ;  Ends scroll.
            ,SB_LEFT            := 6 ;  Scrolls to the upper left.
            ,SB_RIGHT           := 7 ;  Scrolls to the lower right.
            ,SB_LINELEFT        := 0 ;  Scrolls left by one unit.
            ,SB_LINERIGHT       := 1 ;  Scrolls right by one unit.
            ,SB_PAGELEFT        := 2 ;  Scrolls left by the width of the window.
            ,SB_PAGERIGHT       := 3 ;  Scrolls right by the width of the window.
            ,SB_THUMBPOSITION   := 4 ;  The user has dragged the scroll box (thumb) and released the mouse button. The HIWORD indicates the position of the scroll box at the end of the drag operation.
            ,SB_THUMBTRACK      := 5 ;  The user is dragging the scroll box. This message is sent repeatedly until the user releases the mouse button. The HIWORD indicates the position that the scroll box has been dragged to.

            ,SW_ERASE           := 0x0004
            ,SW_INVALIDATE      := 0x0002
            ,SW_SCROLLCHILDREN  := 0x0001
            ,SW_SMOOTHSCROLL    := 0x0010

        hRootWnd:=this._hRootWnd
        if (hWnd!==hRootWnd)
            return
        if (hFocusWnd:=dllCall("User32.dll\GetFocus", "Ptr"))    {
            if (this._getClassName(hFocusWnd)=="Edit" && this._isEditConnectedToUpDown(hFocusWnd))
                return
        }
        nBar:=(Msg==WM_HSCROLL?SB_HORZ:SB_VERT)
        ,lpsi:=buffer(28,0)
        ,numPut("UInt",28,lpsi,0)       ;  cbSize
        ,NumPut("UInt",SIF_ALL,lpsi,4)  ;  fMask
        if (!dllCall("User32.dll\GetScrollInfo", "Ptr",hRootWnd, "Int",nBar, "Ptr",lpsi.Ptr))
            return
        nMin    := numGet(lpsi,8,"Int")
        ,nMax   := numGet(lpsi,12,"Int")
        ,nPage  := numGet(lpsi,16,"Int")
        ,nPos   := numGet(lpsi,20,"Int"), nNewPos:= nPrevPos:= nPos
        ,nTrackPos:=numGet(lpsi,24,"Int")
        switch (this._LOWORD(wParam))
        {
            default:                                return ;  SB_ENDSCROLL
            case SB_LEFT:                           nNewPos:=nMin
            case SB_RIGHT:                          nNewPos:=nMax
            case SB_LINELEFT:                       nNewPos-=30
            case SB_LINERIGHT:                      nNewPos+=30
            case SB_PAGELEFT:
                lpRect:=buffer(16)
                ,dllCall("User32.dll\GetClientRect", "Ptr",hRootWnd, "Ptr",lpRect.Ptr)
                ,clientW:=numGet(lpRect,8,"Int")-numGet(lpRect,0,"Int")
                ,clientH:=numGet(lpRect,12,"Int")-numGet(lpRect,4,"Int")
                switch (nBar)
                {
                    case SB_HORZ:       nNewPos-=clientW
                    default:            nNewPos-=clientH
                }
            case SB_PAGERIGHT:
                lpRect:=buffer(16)
                ,dllCall("User32.dll\GetClientRect", "Ptr",hRootWnd, "Ptr",lpRect.Ptr)
                ,clientW:=numGet(lpRect,8,"Int")-numGet(lpRect,0,"Int")
                ,clientH:=numGet(lpRect,12,"Int")-numGet(lpRect,4,"Int")
                switch (nBar)
                {
                    case SB_HORZ:       nNewPos+=clientW
                    default:            nNewPos+=clientH
                }
            case SB_THUMBPOSITION,SB_THUMBTRACK:    nNewPos:=this._HIWORD(wParam)
        }
        invisibility:=this._coord[hRootWnd].invisibility
        switch (nBar)
        {
            case SB_HORZ:       i:=invisibility.hscroll
            default:            i:=invisibility.vscroll
        }
        nNewPos:=max(nMin,min(nNewPos,nMax-max(nPage-i,0))) ;  The nPos member must specify a value between nMin and nMax - max( nPage– 1, 0).
        ,dx:= dy:= 0
        switch (nBar)
        {
            case SB_HORZ:       dx:=nPrevPos-nNewPos
            default:            dy:=nPrevPos-nNewPos ;  SB_VERT
        }
        dllCall("User32.dll\ScrollWindowEx", "Ptr",hRootWnd, "Int",dx, "Int",dy, "Ptr",0, "Ptr",0, "Ptr",0, "Ptr",0, "UInt",(SW_ERASE|SW_INVALIDATE|SW_SCROLLCHILDREN)&0xffff, "Int") ;  dllCall("User32.dll\ScrollWindow", "Ptr",hRootWnd, "Int",dx, "Int",dy, "Ptr",0, "Ptr",0)
        ,numPut("Int",nNewPos,lpsi,20) ;  nPos
        ,dllCall("User32.dll\SetScrollInfo", "Ptr",hRootWnd, "Int",nBar, "Ptr",lpsi.Ptr, "Int",true, "Int")
    }
    static _onMouseWheel(wParam, _, Msg, hWnd)    {
        static WHEEL_DELTA:=120

            ,MK_CONTROL := 0x0008
            ,MK_LBUTTON := 0x0001
            ,MK_MBUTTON := 0x0010
            ,MK_RBUTTON := 0x0002
            ,MK_SHIFT   := 0x0004
            ,MK_XBUTTON1:= 0x0020
            ,MK_XBUTTON2:= 0x0040

            ,WM_MOUSEWHEEL  := 0x020A
            ,WM_MOUSEHWHEEL := 0x020E
            ,WM_HSCROLL := 0x0114
            ,WM_VSCROLL := 0x0115
            ,WS_HSCROLL := 0x00100000
            ,WS_VSCROLL := 0x00200000

            ,SB_LINELEFT    := 0
            ,SB_LINERIGHT   := 1

            ,STATE_SYSTEM_INVISIBLE     := 0x00008000
            ,STATE_SYSTEM_OFFSCREEN     := 0x00010000
            ,STATE_SYSTEM_PRESSED       := 0x00000008
            ,STATE_SYSTEM_UNAVAILABLE   := 0x00000001
            
            ,UDM_SETPOS32   := (0x0400 + 113) ;  (WM_USER+113)
            ,UDM_GETPOS32   := (0x0400 + 114) ;  (WM_USER+114)

            ,CB_ERR         := -1
            ,CB_GETCOUNT    := 0x0146
            ,CB_GETCURSEL   := 0x0147
            ,CB_SETCURSEL   := 0x014E

        hRootWnd:=this._hRootWnd
        ,lpRect:=buffer(16,0)
        ,dllCall("User32.dll\GetClientRect", "Ptr",hRootWnd, "Ptr",lpRect.Ptr)
        ,client:={}
        ,client.left    := numGet(lpRect,0,"Int")
        ,client.top     := numGet(lpRect,4,"Int")
        ,client.right   := numGet(lpRect,8,"Int")
        ,client.bottom  := numGet(lpRect,12,"Int")
        ,border:=this._coord[hRootWnd].border
        ;-----------------------------------
        ,ret:=0
        ,pm:={}
        ,pm.hWnd:=hRootWnd
        ,wheelCount:=abs((wheelDistance:=this._GET_WHEEL_DELTA_WPARAM(wParam))//WHEEL_DELTA)
        ,keyState:=this._GET_KEYSTATE_WPARAM(wParam)
        switch (Msg)
        {
            case WM_MOUSEWHEEL:     pm.Msg:=(!(keyState&MK_CONTROL)&&(keyState&MK_SHIFT))?WM_HSCROLL:WM_VSCROLL
            default:                pm.Msg:=WM_HSCROLL ;  WM_MOUSEHWHEEL
        }
        pm.wParam:=(wheelDistance<0?SB_LINERIGHT:SB_LINELEFT)
        ,pm.lParam:=0
        if !(border.left<client.left || border.top<client.top || client.right<border.right || client.bottom<border.bottom)    {
            if (pm.Msg==WM_HSCROLL)    {
                style:=this._getWindowStyle(hWnd)
                if (hasScroll:=style&WS_HSCROLL)    {
                    if (bRet:=this._getHScrollBarInfo(hWnd, &objsbi))    {
                        if !(objsbi.rgstate[0]&STATE_SYSTEM_UNAVAILABLE)    {
                            loop (wheelCount*3)
                                dllCall("User32.dll\PostMessage", "Ptr",hWnd, "UInt",pm.Msg, "UPtr",pm.wParam, "Ptr",pm.lParam)
                            return 0
                        }
                    }
                }
            }
            return
        }
        ;-----------------------------------
        if (hFocusWnd:=dllCall("User32.dll\GetFocus", "Ptr"))    {
            style:=this._getWindowStyle(hFocusWnd)
            switch (pm.Msg)
            {
                case WM_VSCROLL:
                    hasScroll:=style&WS_VSCROLL                  
                    if (!hasScroll && Msg==WM_MOUSEWHEEL)    {
                        if (hasScroll:=style&WS_HSCROLL)
                            pm.Msg:=WM_HSCROLL
                    }
                default: ;  WM_HSCROLL
                    hasScroll:=style&WS_HSCROLL
            }
            if (hasScroll)    {
                if (hFocusWnd==hWnd && hFocusWnd!==hRootWnd)    {
                    switch (pm.Msg)
                    {
                        case WM_VSCROLL:        bRet:=this._getVScrollBarInfo(hFocusWnd, &objsbi)
                        default:                bRet:=this._getHScrollBarInfo(hFocusWnd, &objsbi) ;  WM_HSCROLL
                    }
                    if (bRet)    {
                        if !(objsbi.rgstate[0]&STATE_SYSTEM_UNAVAILABLE)    {
                            if (pm.Msg==WM_HSCROLL)    {
                                loop (wheelCount*3)
                                    dllCall("User32.dll\PostMessage", "Ptr",hFocusWnd, "UInt",pm.Msg, "UPtr",pm.wParam, "Ptr",pm.lParam)
                                wheelCount:=0, ret:=0
                            }  else  {
                                wheelCount:=0, ret:=""
                            }
                        }
                    }
                }
            }  else  {
                hComboBoxWnd:=0
                switch (this._getClassName(hFocusWnd))
                {
                    case "ComboBox":                hComboBoxWnd:=hFocusWnd
                    case "Edit": ;  UpDown
                        if (hUpDownWnd:=this._isEditConnectedToUpDown(hFocusWnd))    {
                            wheelCount:=0, ret:=0
                            ,pos32:=dllCall("User32.dll\SendMessage", "Ptr",hUpDownWnd, "UInt",UDM_GETPOS32, "UPtr",0, "Ptr",0)
                            ,dllCall("User32.dll\SendMessage", "Ptr",hUpDownWnd, "UInt",UDM_SETPOS32, "UPtr",0, "Ptr",pos32+wheelDistance//WHEEL_DELTA)
                            /*
                             About Up-Down Controls
                            https://learn.microsoft.com/en-us/windows/win32/controls/up-down-controls
                             Up-Down Control
                            https://learn.microsoft.com/en-us/windows/win32/controls/up-down-control-reference
                            */
                        }  else if (hComboBoxWnd:=this._isEditConnectedToComboBox(hFocusWnd))    {
                            /*
                             ComboBox Control Messages
                            https://learn.microsoft.com/en-us/windows/win32/controls/bumper-combobox-control-reference-messages
                            */
                        }
                }
                if (hComboBoxWnd)    {
                    wheelCount:=0, ret:=0                           
                    ,count:=dllCall("User32.dll\SendMessage", "Ptr",hComboBoxWnd, "UInt",CB_GETCOUNT, "UPtr",0, "Ptr",0, "Int")
                    if (count!==CB_ERR && count!==0)    {
                        curSel:=dllCall("User32.dll\SendMessage", "Ptr",hComboBoxWnd, "UInt",CB_GETCURSEL, "UPtr",0, "Ptr",0, "Int")
                        ,newSel:=curSel==CB_ERR?0:max(0,min(count,curSel-wheelDistance//WHEEL_DELTA))
                        ,dllCall("User32.dll\SendMessage", "Ptr",hComboBoxWnd, "UInt",CB_SETCURSEL, "Int",newSel, "Ptr",0, "Ptr")
                    }
                }
            }
        }
        ;-----------------------------------
        loop (wheelCount)
            dllCall("User32.dll\PostMessage", "Ptr",pm.hWnd, "UInt",pm.Msg, "UPtr",pm.wParam, "Ptr",pm.lParam)
        return ret
    }
    static _onSizing(_*)    {
        static SIF_DISABLENOSCROLL  := 0x0008
            ,SIF_PAGE               := 0x0002
            ,SIF_POS                := 0x0004
            ,SIF_RANGE              := 0x0001

            ,SB_HORZ                := 0
            ,SB_VERT                := 1

            ,RDW_ERASE              := 0x0004
            ,RDW_FRAME              := 0x0400
            ,RDW_INTERNALPAINT      := 0x0002
            ,RDW_INVALIDATE         := 0x0001
            ,RDW_NOERASE            := 0x0020
            ,RDW_NOFRAME            := 0x0800
            ,RDW_NOINTERNALPAINT    := 0x0010
            ,RDW_VALIDATE           := 0x0008
            ,RDW_ERASENOW           := 0x0200
            ,RDW_UPDATENOW          := 0x0100

            ,SW_ERASE           := 0x0004
            ,SW_INVALIDATE      := 0x0002
            ,SW_SCROLLCHILDREN  := 0x0001
            ,SW_SMOOTHSCROLL    := 0x0010

            ,RGN_AND                := 1
            ,RGN_COPY               := 5
            ,RGN_DIFF               := 4
            ,RGN_OR                 := 2
            ,RGN_XOR                := 3

        hRootWnd:=this._hRootWnd
        ,lpsi:=buffer(28,0)
        ,numPut("UInt",28,lpsi,0)       ;  cbSize
        ,numPut("UInt",SIF_POS,lpsi,4)  ;  fMask
        ,dllCall("User32.dll\GetScrollInfo", "Ptr",hRootWnd, "Int",SB_HORZ, "Ptr",lpsi.Ptr)
        ,nPosHorzPrev:=numGet(lpsi,20,"Int")
        ,lpsi:=buffer(28,0)
        ,numPut("UInt",28,lpsi,0)       ;  cbSize
        ,NumPut("UInt",SIF_POS,lpsi,4)  ;  fMask
        ,dllCall("User32.dll\GetScrollInfo", "Ptr",hRootWnd, "Int",SB_VERT, "Ptr",lpsi.Ptr)
        ,nPosVertPrev:=numGet(lpsi,20,"Int")
        ;-----------------------------------
        ,lpRect:=buffer(16,0)
        ,dllCall("User32.dll\GetClientRect", "Ptr",hRootWnd, "Ptr",lpRect.Ptr)
        ,client:={}
        ,client.left    := numGet(lpRect,0,"Int")
        ,client.top     := numGet(lpRect,4,"Int")
        ,client.right   := numGet(lpRect,8,"Int")
        ,client.bottom  := numGet(lpRect,12,"Int")
        ,client.width   := client.right-client.left
        ,client.height  := client.bottom-client.top
        ,border:=this._coord[hRootWnd].border
        ,invisibility:=this._coord[hRootWnd].invisibility
        ;-----------------------------------
        ,lpsi:=buffer(28,0)
        ,numPut("UInt",28,lpsi,0), numPut("UInt",SIF_PAGE|SIF_RANGE,lpsi,4)
        ,nPage:=client.height
        ,nMax:=border.bottom-border.top-invisibility.hscroll
        if (this._getHScrollBarInfo(hRootWnd, &objsbi))    {
            hscrollBarHeight:=objsbi.rcScrollBar.bottom-objsbi.rcScrollBar.top
            if (!invisibility.hscroll)
                nPage-=hscrollBarHeight, nMax-=hscrollBarHeight
            else if (!this._scrollInvisibilityFromState(objsbi.rgstate[0]))
                nPage+=hscrollBarHeight
        }
        numPut("UInt",nPage,lpsi,16)    ;  nPage
        ,numPut("Int",nMax,lpsi,12)     ;  nMax
        ,dllCall("User32.dll\SetScrollInfo", "Ptr",hRootWnd, "Int",SB_VERT, "Ptr",lpsi.Ptr, "Int",true)
        ;-----------------------------------
        ,lpsi:=buffer(28,0)
        ,numPut("UInt",28,lpsi,0), numPut("UInt",SIF_PAGE|SIF_RANGE,lpsi,4)
        ,nPage:=client.width
        ,nMax:=border.right-border.left-invisibility.vscroll
        if (this._getVScrollBarInfo(hRootWnd, &objsbi))    {
            vscrollBarWidth:=objsbi.rcScrollBar.right-objsbi.rcScrollBar.left
            if (!invisibility.vscroll)
                nPage-=vscrollBarWidth, nMax-=vscrollBarWidth
            else if (!this._scrollInvisibilityFromState(objsbi.rgstate[0]))
                nPage+=vscrollBarWidth
        }
        numPut("UInt",nPage,lpsi,16)    ;  nPage
        ,numPut("Int",nMax,lpsi,12)     ;  nMax
        ,dllCall("User32.dll\SetScrollInfo", "Ptr",hRootWnd, "Int",SB_HORZ, "Ptr",lpsi.Ptr, "Int",true)
        ;-----------------------------------       
        ,lpsi:=buffer(28,0)
        ,numPut("UInt",28,lpsi,0)       ;  cbSize
        ,NumPut("UInt",SIF_POS,lpsi,4)  ;  fMask
        ,dllCall("User32.dll\GetScrollInfo", "Ptr",hRootWnd, "Int",SB_HORZ, "Ptr",lpsi.Ptr)
        ,nPosHorzCurr:=numGet(lpsi,20,"Int")
        ,lpsi:=buffer(28,0)
        ,numPut("UInt",28,lpsi,0)       ;  cbSize
        ,NumPut("UInt",SIF_POS,lpsi,4)  ;  fMask
        ,dllCall("User32.dll\GetScrollInfo", "Ptr",hRootWnd, "Int",SB_VERT, "Ptr",lpsi.Ptr)
        ,nPosVertCurr:=numGet(lpsi,20,"Int")
        ,dx:=nPosHorzPrev-nPosHorzCurr
        ,dy:=nPosVertPrev-nPosVertCurr
        if (dx||dy)    {
            dllCall("User32.dll\ScrollWindowEx", "Ptr",hRootWnd, "Int",dx, "Int",dy, "Ptr",0, "Ptr",0, "Ptr",0, "Ptr",0, "UInt",(SW_ERASE|SW_INVALIDATE|SW_SCROLLCHILDREN)&0xffff, "Int") ;  dllCall("User32.dll\ScrollWindow", "Ptr",hRootWnd, "Int",dx, "Int",dy, "Ptr",0, "Ptr",0)
            ,hrgnDst:=dllCall("Gdi32.dll\CreateRectRgn", "Int",0, "Int",0, "Int",0, "Int",0, "Ptr")
            ,hrgnSrc1:=dllCall("Gdi32.dll\CreateRectRgn", "Int",0, "Int",0, "Int",dx, "Int",client.height, "Ptr")
            ,hrgnSrc2:=dllCall("Gdi32.dll\CreateRectRgn", "Int",0, "Int",0, "Int",client.width, "Int",dy, "Ptr")
            ,dllCall("Gdi32.dll\CombineRgn", "Ptr",hrgnDst, "Ptr",hrgnSrc1, "Ptr",hrgnSrc2, "Int",RGN_OR, "Int")
            ,dllCall("User32.dll\RedrawWindow", "Ptr",hRootWnd, "Ptr",0, "Ptr",hrgnDst, "UInt",RDW_UPDATENOW) ;  dllCall("User32.dll\RedrawWindow", "Ptr",hRootWnd, "Ptr",0, "Ptr",0, "UInt",RDW_INVALIDATE|RDW_ERASE|RDW_UPDATENOW)
            ,dllCall("Gdi32.dll\DeleteObject", "Ptr",hrgnDst)
            ,dllCall("Gdi32.dll\DeleteObject", "Ptr",hrgnSrc1)
            ,dllCall("Gdi32.dll\DeleteObject", "Ptr",hrgnSrc2)
        }
    }
    static _onExitSizeMove(_1, _2, _3, hWnd)    {
        if (hWnd==this._hRootWnd)
            dllCall("User32.dll\SetFocus", "Ptr",0, "Ptr")
    }
    ;--------------------------------------------------
    static _getHScrollBarInfo(hWnd, &objsbi)    {
        static OBJID_HSCROLL:=0xFFFFFFFA
        return this._getScrollBarInfo(hWnd,OBJID_HSCROLL,&objsbi)
    }
    static _getVScrollBarInfo(hWnd, &objsbi)     {
        static OBJID_VSCROLL:=0xFFFFFFFB
        return this._getScrollBarInfo(hWnd,OBJID_VSCROLL,&objsbi)
    }
    static _scrollInvisibilityFromState(rgstate:=0)    {
        static STATE_SYSTEM_INVISIBLE:=0x00008000
        return !!(rgstate&STATE_SYSTEM_INVISIBLE)
    }
    static _getScrollBarInfo(hWnd, idObject, &objsbi)    {
        objsbi:={cbSize:"",rcScrollBar:{left:"",top:"",right:"",bottom:""},dxyLineButton:"",xyThumbTop:"",xyThumbBottom:"",reserved:"",rgstate:map(0,"", 1,"", 2,"", 3,"", 4,"", 5,"")}
        ,psbi:=buffer(60,0)
        ,numPut("UInt",60,psbi,0)
        if (bRet:=dllCall("User32.dll\GetScrollBarInfo", "Ptr",hWnd, "Int",idObject, "Ptr",psbi.Ptr))    {
             objsbi.cbSite:=numGet(psbi,0,"UInt")
            ,objsbi.rcScrollBar.left:=numGet(psbi,4,"Int")
            ,objsbi.rcScrollBar.top:=numGet(psbi,8,"Int")
            ,objsbi.rcScrollBar.right:=numGet(psbi,12,"Int")
            ,objsbi.rcScrollBar.bottom:=numGet(psbi,16,"Int")
            ,objsbi.dxyLineButton:=numGet(psbi,20,"Int")
            ,objsbi.xyThumbTop:=numGet(psbi,24,"Int")
            ,objsbi.xyThumbBottom:=numGet(psbi,28,"Int")
            ,objsbi.reserved:=numGet(psbi,32,"Int")
            loop 6
                objsbi.rgstate[A_Index-1]:=numGet(psbi,32+A_Index*4,"Int")
        }
        return bRet
    }
    static _getWindowStyle(hWnd)    {
        static GWL_STYLE:=-16
        return dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",hWnd, "Int",GWL_STYLE, (A_PtrSize==8?"Ptr":"Int"))
    }
    static _getClassName(hWnd, nMaxCount?)    {
        static MAX_CLASS_NAME:=1024
        if (!isSet(nMaxCount))
            nMaxCount:=MAX_CLASS_NAME
        lpClassName:=buffer(2*nMaxCount, 0)
        return (dllCall("User32.dll\GetClassName", "Ptr",hWnd, "Ptr",lpClassName.Ptr, "Int",nMaxCount, "Int"))
            ?strGet(lpClassName.Ptr)
            :""
    }
    static _isEditConnectedToUpDown(hWnd)    {
        static GW_HWNDNEXT  := 2
            ,UPDOWN_CLASS   := "msctls_updown32"
        return (this._getClassName(hNextWnd:=dllCall("User32.dll\GetWindow", "Ptr",hWnd, "UInt",GW_HWNDNEXT))==UPDOWN_CLASS
            ?hNextWnd
            :0)
    }
    static _isEditConnectedToComboBox(hWnd)    {
        static GA_PARENT    := 1
            ,WC_COMBOBOX    := "ComboBox"
        return (this._getClassName(hParentWnd:=dllCall("User32.dll\GetAncestor", "Ptr",hWnd, "UInt",GA_PARENT))==WC_COMBOBOX
            ?hParentWnd
            :0)
    }
    static _getSystemMetrics(nIndex) => dllCall("User32.dll\GetSystemMetrics", "Int",nIndex, "Int")
    ;--------------------------------------------------    
    static _HIWORD(l) => (l<<32>>>48)                               ;  C++ #define HIWORD(l) ((WORD)((((DWORD_PTR)(l)) >> 16) & 0xffff))
    static _LOWORD(l) => (l&0xffff) ;  (l<<48>>>48)                 ;  C++ #define LOWORD(l) ((WORD)(((DWORD_PTR)(l)) & 0xffff))
    static _GET_WHEEL_DELTA_WPARAM(wParam) => (wParam<<32>>48)      ;  C++ #define GET_WHEEL_DELTA_WPARAM(wParam) ((short)HIWORD(wParam))
    static _GET_KEYSTATE_WPARAM(wParam) => (wParam&0xffff)          ;  C++ #define GET_KEYSTATE_WPARAM(wParam) (LOWORD(wParam))
}
/*
#Requires AutoHotkey v2.0
#SingleInstance Force
ScrollableGui.init()
showGui()
F2::showGui()
F3::    {
    global myGui
    if (isSet(myGui) && myGui is gui)
        myGui.destroy(), myGui := ""
}
showGui()    {
    global myGui
    WS_HSCROLL := 0x00100000
    WS_VSCROLL := 0x00200000
    if (isSet(myGui) && myGui is gui)
        return
    prevIC := critical("On")
    myGui := gui()
    myGui.onEvent("Close", myGui_Close)
    myGui.add("Edit", "w480 readonly", "Universal Declaration of Human Rights")
    myGui.add("Edit", "w480 r5 readonly -wrap", fa6ee997_16a7_44c4_9b05_008ec75510b6("A"))
    style := WS_HSCROLL|WS_VSCROLL
    myGui.add("Edit", "w480 r6 readonly +" style, fa6ee997_16a7_44c4_9b05_008ec75510b6("B"))
    myGui.add("Edit", "w480 r6 readonly +" WS_HSCROLL " -" WS_VSCROLL, fa6ee997_16a7_44c4_9b05_008ec75510b6("C"))
    myGui.add("Link",, "<a href=`"https://www.un.org/sites/un2.un.org/files/2021/03/udhr.pdf`">Universal Declaration of Human Rights (UDHR)</a>")
    myGui.add("Edit", "w480", "The work of the United Nations covers five main areas:")
    myGui.add("Edit", "w480")
    myGui.add("UpDown", "Range1-365")
    myGui.add("ComboBox", "w480", ["Peace","Dignity","Equality"])
    myGui.add("DropDownList", "w480", ["Maintain International Peace and Security","Protect Human Rights","Deliver Humanitarian Aid","Support Sustainable Development and Climate Action","Uphold International Law"])
    myGui.add("Button", "w480", "Button")
    style := 0 ;  WS_HSCROLL|WS_VSCROLL
    myGui.opt("+MaxSize +Resize +" style)
    myGui.Title := "United Nations"
    myGui.show("AutoSize")
    ScrollableGui.register(myGui.Hwnd)
    critical(prevIC)
}
myGui_Close(thisGui)    {
   global myGui
   myGui.destroy()
   myGui := ""
   return 0
}
fa6ee997_16a7_44c4_9b05_008ec75510b6(type)    {
    switch (type)
    {
        case "A":   return "
            (LTrim0
Preamble
Whereas recognition of the inherent dignity and of the equal and inalienable
rights of all members of the human family is the foundation of freedom, justice
and peace in the world,
Whereas disregard and contempt for human rights have resulted in barbarous
acts which have outraged the conscience of mankind, and the advent of a world
in which human beings shall enjoy freedom of speech and belief and freedom
from fear and want has been proclaimed as the highest aspiration of the common
people,
Whereas it is essential, if man is not to be compelled to have recourse, as a last
resort, to rebellion against tyranny and oppression, that human rights should be
protected by the rule of law,
Whereas it is essential to promote the development of friendly relations between
nations,
Whereas the peoples of the United Nations have in the Charter reaffirmed their
faith in fundamental human rights, in the dignity and worth of the human person
and in the equal rights of men and women and have determined to promote
social progress and better standards of life in larger freedom,
Whereas Member States have pledged themselves to achieve, in cooperation
with the United Nations, the promotion of universal respect for and observance of
human rights and fundamental freedoms,
Whereas a common understanding of these rights and freedoms is of the
greatest importance for the full realization of this pledge,
Now, therefore,
The General Assembly,
Proclaims this Universal Declaration of Human Rights as a common standard of
achievement for all peoples and all nations, to the end that every individual and
every organ of society, keeping this Declaration constantly in mind, shall strive by
teaching and education to promote respect for these rights and freedoms and by
progressive measures, national and international, to secure their universal and
effective recognition and observance, both among the peoples of Member States
themselves and among the peoples of territories under their jurisdiction. 
)"
        case "B":   return "
(LTrim0
Article I
All human beings are born free and equal in dignity and rights. They are endowed with reason and conscience and should act towards one another in a spirit of brotherhood.
Article 2
Everyone is entitled to all the rights and freedoms set forth in this Declaration, without distinction of any kind, such as race, colour, sex, language, religion, political or other opinion, national or social origin, property, birth or other status.
Furthermore, no distinction shall be made on the basis of the political, jurisdictional or international status of the country or territory to which a person belongs, whether it be independent, trust, non-self-governing or under any other limitation of sovereignty.
Article 3
Everyone has the right to life, liberty and the security of person.
Article 4
No one shall be held in slavery or servitude; slavery and the slave trade shall be prohibited in all their forms.
Article 5
No one shall be subjected to torture or to cruel, inhuman or degrading treatment or punishment.
Article 6
Everyone has the right to recognition everywhere as a person before the law.
Article 7
All are equal before the law and are entitled without any discrimination to equal protection of the law. All are entitled to equal protection against any
discrimination in violation of this Declaration and against any incitement to such discrimination.
Article 8
Everyone has the right to an effective remedy by the competent national tribunals for acts violating the fundamental rights granted him by the constitution or by law.
Article 9
No one shall be subjected to arbitrary arrest, detention or exile.
Article 10
Everyone is entitled in full equality to a fair and public hearing by an independent and impartial tribunal, in the determination of his rights and obligations and of any criminal charge against him.
Article 11
1. Everyone charged with a penal offence has the right to be presumed innocent until proved guilty according to law in a public trial at which he has had all the guarantees necessary for his defence.
2. No one shall be held guilty of any penal offence on account of any act or omission which did not constitute a penal offence, under national or international law, at the time when it was committed. Nor shall a heavier penalty be imposed than the one that was applicable at the time the penal offence was committed.
Article 12
No one shall be subjected to arbitrary interference with his privacy, family, home or correspondence, nor to attacks upon his honour and reputation. Everyone has the right to the protection of the law against such interference or attacks.
Article 13
1. Everyone has the right to freedom of movement and residence within the borders of each State.
2. Everyone has the right to leave any country, including his own, and to return to his country.
Article 14
1. Everyone has the right to seek and to enjoy in other countries asylum from persecution.
2. This right may not be invoked in the case of prosecutions genuinely arising from non-political crimes or from acts contrary to the purposes and principles of the United Nations.
Article 15
1. Everyone has the right to a nationality.
2. No one shall be arbitrarily deprived of his nationality nor denied the right to change his nationality.
)"
        case "C":   return "
(LTrim0
Article 16
1. Men and women of full age, without any limitation due to race, nationality or religion, have the right to marry and to found a family. They are entitled to equal rights as to marriage, during marriage and at its dissolution.
2. Marriage shall be entered into only with the free and full consent of the intending spouses.
3. The family is the natural and fundamental group unit of society and is entitled to protection by society and the State.
Article 17
1. Everyone has the right to own property alone as well as in association with others.
2. No one shall be arbitrarily deprived of his property.
Article 18
Everyone has the right to freedom of thought, conscience and religion; this right includes freedom to change his religion or belief, and freedom, either alone or in
community with others and in public or private, to manifest his religion or belief in teaching, practice, worship and observance.
Article 19
Everyone has the right to freedom of opinion and expression; this right includes freedom to hold opinions without interference and to seek, receive and impart information and ideas through any media and regardless of frontiers.
Article 20
1. Everyone has the right to freedom of peaceful assembly and association.
2. No one may be compelled to belong to an association.
Article 21
1. Everyone has the right to take part in the government of his country, directly or through freely chosen representatives.
2. Everyone has the right to equal access to public service in his country.
3. The will of the people shall be the basis of the authority of government;
this will shall be expressed in periodic and genuine elections which shall be by universal and equal suffrage and shall be held by secret vote or by equivalent free voting procedures.
Article 22
Everyone, as a member of society, has the right to social security and is entitled to realization, through national effort and international co-operation and in accordance with the organization and resources of each State, of the economic, social and cultural rights indispensable for his dignity and the free development of his personality.
Article 23
1. Everyone has the right to work, to free choice of employment, to just and favourable conditions of work and to protection against unemployment.
2. Everyone, without any discrimination, has the right to equal pay for equal work.
3. Everyone who works has the right to just and favourable remuneration ensuring for himself and his family an existence worthy of human dignity, and supplemented, if necessary, by other means of social protection.
4. Everyone has the right to form and to join trade unions for the protection of his interests.
Article 24
Everyone has the right to rest and leisure, including reasonable limitation of working hours and periodic holidays with pay.
Article 25
1. Everyone has the right to a standard of living adequate for the health and well-being of himself and of his family, including food, clothing, housing
and medical care and necessary social services, and the right to security in the event of unemployment, sickness, disability, widowhood, old age or other lack of livelihood in circumstances beyond his control.
2. Motherhood and childhood are entitled to special care and assistance. All children, whether born in or out of wedlock, shall enjoy the same social protection.
Article 26
1. Everyone has the right to education. Education shall be free, at least in the elementary and fundamental stages. Elementary education shall be compulsory. Technical and professional education shall be made generally available and higher education shall be equally accessible to all on the basis of merit.
2. Education shall be directed to the full development of the human personality and to the strengthening of respect for human rights and fundamental freedoms. It shall promote understanding, tolerance and friendship among all nations, racial or religious groups, and shall further the activities of the United Nations for the maintenance of peace.
3. Parents have a prior right to choose the kind of education that shall be given to their children.
Article 27
1. Everyone has the right freely to participate in the cultural life of the community, to enjoy the arts and to share in scientific advancement and its benefits.
2. Everyone has the right to the protection of the moral and material interests resulting from any scientific, literary or artistic production of which he is the author.
Article 28
Everyone is entitled to a social and international order in which the rights and freedoms set forth in this Declaration can be fully realized.
Article 29
1. Everyone has duties to the community in which alone the free and full development of his personality is possible.
2. In the exercise of his rights and freedoms, everyone shall be subject only to such limitations as are determined by law solely for the purpose of securing due recognition and respect for the rights and freedoms of others and of meeting the just requirements of morality, public order and the general welfare in a democratic society.
3. These rights and freedoms may in no case be exercised contrary to the purposes and principles of the United Nations.
Article 30
Nothing in this Declaration may be interpreted as implying for any State, group or person any right to engage in any activity or to perform any act aimed at the destruction of any of the rights and freedoms set forth herein. 
)"
    }
}
*/
