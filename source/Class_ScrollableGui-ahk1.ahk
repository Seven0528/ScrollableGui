class ScrollableGui
{
    /*
    ScrollableGui Class
    Version: 1.0.1
    Compatible with: AutoHotkey v1.1+
    Copyright (c) 2024 SevenKeyboard Ltd.

    Licensed under the MIT License.
    You may obtain a copy of the License at:
    https://github.com/Seven0528/ScrollableGui/blob/v1.1/LICENSE

    Official Repository:
    https://github.com/Seven0528/ScrollableGui

    Description: 
    This class provides scrollable GUI functionality with dynamic size updates.
    It supports horizontal and vertical scrolling, and allows for customization
    of scroll behavior, including focus-based inner scrolling.
    */
    init()    {
        this.registerWndProc(-1,-1)
    }
    static _coord:=object(), _opt:=object(), _hRootWnd:=0
    ;--------------------------------------------------
    register(hWnd, innerScrollOnFocus:=true)    {
        static SIF_DISABLENOSCROLL  := 0x0008
            ,SIF_PAGE               := 0x0002
            ,SIF_POS                := 0x0004
            ,SIF_RANGE              := 0x0001
            ,SB_HORZ    := 0
            ,SB_VERT    := 1

            ,WS_HSCROLL := 0x00100000
            ,WS_VSCROLL := 0x00200000

        if (!this._isWindow(hWnd:=this._resolveHwnd(hWnd)))
            return false
        if (!this._coord.hasKey(hWnd))    {
            this._coord[hWnd]:={border:{left:0,top:0,right:0,bottom:0}
                ,invisibility:{hscroll:true,vscroll:true}}
        }
        varSetCapacity(lpRect,16,0)
        ,dllCall("User32.dll\GetClientRect", "Ptr",hWnd, "Ptr",&lpRect)
        ,client:={}
        ,client.left    := numGet(lpRect,0,"Int")
        ,client.top     := numGet(lpRect,4,"Int")
        ,client.right   := numGet(lpRect,8,"Int")
        ,client.bottom  := numGet(lpRect,12,"Int")
        ,style:=this._getWindowStyle(hWnd)
        if (this._coord[hWnd].invisibility.hscroll:=!(style&WS_HSCROLL))    {
            if (this._getVScrollBarInfo(hWnd, objsbi))
                client.right+=objsbi.rcScrollBar.right-objsbi.rcScrollBar.left ;  vscrollBarWidth
        }
        if (this._coord[hWnd].invisibility.vscroll:=!(style&WS_VSCROLL))    {
            if (this._getHScrollBarInfo(hWnd, objsbi))
                client.bottom+=objsbi.rcScrollBar.bottom-objsbi.rcScrollBar.top ;  hscrollBarHeight
        }
        for k,v in this._coord[hWnd].border
            this._coord[hWnd].border[k]:=client[k]
        border:=this._coord[hWnd].border
        ,invisibility:=this._coord[hWnd].invisibility
        ,this._opt[hWnd] := {innerScrollOnFocus:(!!innerScrollOnFocus)}
        ;-----------------------------------
        ,varSetCapacity(lpsi,28,0)
        ,numPut(28,lpsi,0,"UInt"), numPut(SIF_PAGE|SIF_POS|SIF_RANGE,lpsi,4,"UInt")
        ,width:=border.right-border.left
        ,numPut(0,lpsi,8,"Int")         ;  nMin
        ,numPut(width-invisibility.vscroll,lpsi,12,"Int")  ;  nMax
        ,numPut(width,lpsi,16,"UInt")   ;  The nPage member must specify a value from 0 to nMax - nMin +1
        ,dllCall("User32.dll\SetScrollInfo", "Ptr",hWnd, "Int",SB_HORZ, "Ptr",&lpsi, "Int",true, "Int")
        ;-----------------------------------
        ,varSetCapacity(lpsi,28,0)
        ,numPut(28,lpsi,0,"UInt"), numPut(SIF_PAGE|SIF_POS|SIF_RANGE,lpsi,4,"UInt")
        ,height:=border.bottom-border.top      
        ,numPut(0,lpsi,8,"Int")         ;  nMin
        ,numPut(height-invisibility.hscroll,lpsi,12,"Int") ;  nMax
        ,numPut(height,lpsi,16,"UInt")  ;  nPage
        ,dllCall("User32.dll\SetScrollInfo", "Ptr",hWnd, "Int",SB_VERT, "Ptr",&lpsi, "Int",true, "Int")
        return true
    }
    unregister(hWnd)    {
        if (this._coord.hasKey(hWnd:=this._resolveHwnd(hWnd)))    {
            this._coord.delete(hWnd)
            ,this._opt.delete(hWnd)
            return true
        }
        return false
    }
    enableInnerScrollOnFocus(hWnd, onoff:=true)    {
        if (this._opt.hasKey(hWnd:=this._resolveHwnd(hWnd)))
            this._opt[hWnd].innerScrollOnFocus := (!!onoff)
    }
    isRegistered(hWnd)    {
        return (this._coord.hasKey(hWnd:=this._resolveHwnd(hWnd)))
    }
    syncSize(hWnd)    {
        static GA_ROOT:=2
        if (!this._isWindow(hWnd:=this._resolveHwnd(hWnd)))
            return false
        if (!this.isRegistered(hRootWnd:=dllCall("User32.dll\GetAncestor", "Ptr",hWnd, "UInt",GA_ROOT, "Ptr")))
            return false
        this._hRootWnd:=hRootWnd
        ,this._onSizing()
        return true
    }
    ;--------------------------------------------------
    calculateInnerControlsSize(hWnd, byRef left:="", byRef top:="", byRef right:="", byRef bottom:="", visibleControlsOnly:=true)    {
        if (!this._isWindow(hWnd:=this._resolveHwnd(hWnd)))
            return false
        setBatchLines % format("{2}",prevBL:=A_BatchLines,-1)
        left:= top:= right:= bottom:= 0
        detectHiddenWindows % format("{2}",prevDHW:=A_DetectHiddenWindows,"On")
        setWinDelay % format("{2}",prevWD:=A_WinDelay,-1)
        winGet controlListHwnd, ControlListHwnd, % "ahk_id " hWnd
        if (controlListHwnd!=="")    {
            left:= top:= 0x7FFFFFFFFFFFFFFF, right:= bottom:= 0
            loop Parse, % controlListHwnd, % "`n"
            {
                if (visibleControlsOnly)    {
                    controlGet visible, Visible,,, % "ahk_id " A_LoopField
                    if (!visible)
                        continue
                }
                controlGetPos cntlX1, cntlY1, cntlW, cntlH,, % "ahk_id " A_LoopField
                cntlX2:=cntlX1+cntlW, cntlY2:=cntlY1+cntlH
                ,left  := min(left, cntlX1)
                ,top   := min(top, cntlY1)
                ,right := max(right, cntlX2)
                ,bottom:= max(bottom, cntlY2)
            }
        }
        detectHiddenWindows % prevDHW
        setWinDelay % prevWD
        setBatchLines % prevBL
        return true
    }
    ;--------------------------------------------------
    getBoundary(hWnd, byRef width:="", byRef height:="")    {
        width:= height:= ""
        if (boundarySize:=this._getRegisteredBoundarySize(hWnd:=this._resolveHwnd(hWnd)))    {
            width:=boundarySize.right - boundarySize.left
            ,height:=boundarySize.bottom - boundarySize.top
            return true
        }
        return false
    }
    updateBoundary(guiName:="", guiDpiScaled:=true, newWidth:="", newHeight:="", setMaxSize:=true)    {
        if (guiName=="")
            guiName:=A_DefaultGui
        gui % guiName ":+LastFoundExist"
        hWnd := winExist()
        if (!hWnd)
            return false
        hWnd:=this._resolveHwnd(hWnd)
        if (!this._coord.hasKey(hWnd))
        || (newWidth=="" && newHeight=="")
            return false
        border:=this._coord[hWnd].border
        ,prevWidth:=border.right-border.left
        ,prevHeight:=border.bottom-border.top
        ,this._registerBoundarySize(hWnd,,, (newWidth!=="" ? border.left + newWidth : ""), (newHeight!=="" ? border.top + newHeight : ""))
        if (setMaxSize)    {
            showOptions:=""
            if (newWidth<prevWidth)
                showOptions.="w" newWidth
            if (newHeight<prevHeight)
                showOptions.=(showOptions==""?"":" ") "h" newHeight
            switch (!!guiDpiScaled)
            {
                default:
                    gui % guiName ":+MaxSize" newWidth "x" newHeight
                    if (showOptions !== "")
                        gui % guiName ":Show", % showOptions
                case true:
                    critical % format("{2}",prevIC:=A_IsCritical,"On")
                    gui % guiName ":-DPIScale"
                    gui % guiName ":+MaxSize" newWidth "x" newHeight
                    if (showOptions !== "")
                        gui % guiName ":Show", % showOptions
                    gui % guiName ":+DPIScale"
                    critical % prevIC
            }
        }
        this.syncSize(hWnd)
        return true
    }
    _getRegisteredBoundarySize(hWnd)    {
        return this._coord.hasKey(hWnd)?this._coord[hWnd].border.clone():""
    }
    _registerBoundarySize(hWnd, left:="", top:="", right:="", bottom:="")    {
        if (!this._coord.hasKey(hWnd))
            return false
        currBorder:=this._coord[hWnd].border
        ,newBorder:={left:(left!==""?left:currBorder.left)
            ,top:(top!==""?top:currBorder.top)
            ,right:(right!==""?right:currBorder.right)
            ,bottom:(bottom!==""?bottom:currBorder.bottom)}
        if (newBorder.right < newBorder.left || newBorder.bottom < newBorder.top)
            return false
        this._coord[hWnd].border:=newBorder
        return true
    }
    /*
    static setOptions(hWnd, option?)    { ;  Not implemented yet.
    }
    */
    ;--------------------------------------------------
    registerWndProc(Msg:=-1, maxThreads:=-1)    {
        static WM_DESTROY:=0x0002,WM_HSCROLL:=0x0114, WM_VSCROLL:=0x0115, WM_LBUTTONDOWN:=0x0201, WM_MOUSEWHEEL:=0x020A, WM_MOUSEHWHEEL:=0x020E, WM_SIZING:=0x0214, WM_EXITSIZEMOVE:=0x0232
        if (!this.hasKey("_obmWndProc"))
            this._objbmWndProc:=objBindMethod(this,"wndProc")
        objbm:=this._objbmWndProc
        if (Msg!==-1)    {
            onMessage(Msg,objbm,maxThreads)
        }  else  {
            for _,Msg in [WM_DESTROY,WM_HSCROLL,WM_VSCROLL,WM_LBUTTONDOWN,WM_MOUSEWHEEL,WM_MOUSEHWHEEL,WM_SIZING,WM_EXITSIZEMOVE]
                onMessage(Msg,objbm,maxThreads)
        }
    }
    wndProc(wParam, lParam, Msg, hWnd)    { ;  UPtr  Ptr  UInt  Ptr
        static GA_ROOT:=2
            ,WM_DESTROY:=0x0002,WM_HSCROLL:=0x0114, WM_VSCROLL:=0x0115, WM_LBUTTONDOWN:=0x0201, WM_MOUSEWHEEL:=0x020A, WM_MOUSEHWHEEL:=0x020E, WM_SIZING:=0x0214, WM_EXITSIZEMOVE:=0x0232
        if (Msg==WM_DESTROY)    {
            this.unregister(hWnd)
            return
        }
        critical % format("{2}",prevIC:=A_IsCritical,"On")
        setBatchLines % format("{2}",prevBL:=A_BatchLines,-1)
        ret:=""
        if (this.isRegistered(this._hRootWnd:=dllCall("User32.dll\GetAncestor", "Ptr",hWnd, "UInt",GA_ROOT, "Ptr")&0xffffffff))    {
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
        setBatchLines % prevBL
        critical % prevIC
        return ret
    }
    ;--------------------------------------------------
    CXVSCROLL    {
        get  {
            static SM_CXVSCROLL:=2
            return this._getSystemMetrics(SM_CXVSCROLL)
        }
    }
    CYHSCROLL    {
        get  {
            static SM_CYHSCROLL:=3
            return this._getSystemMetrics(SM_CYHSCROLL)
        }
    }
    ;--------------------------------------------------
    _onScroll(wParam, _, Msg, hWnd)    {
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
        ,varSetCapacity(lpsi,28,0)
        ,numPut(28,lpsi,0,"UInt")       ;  cbSize
        ,NumPut(SIF_ALL,lpsi,4,"UInt")  ;  fMask
        if (!dllCall("User32.dll\GetScrollInfo", "Ptr",hRootWnd, "Int",nBar, "Ptr",&lpsi))
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
                varSetCapacity(lpRect,16)
                ,dllCall("User32.dll\GetClientRect", "Ptr",hRootWnd, "Ptr",&lpRect)
                ,clientW:=numGet(lpRect,8,"Int")-numGet(lpRect,0,"Int")
                ,clientH:=numGet(lpRect,12,"Int")-numGet(lpRect,4,"Int")
                switch (nBar)
                {
                    case SB_HORZ:       nNewPos-=clientW
                    default:            nNewPos-=clientH
                }
            case SB_PAGERIGHT:
                varSetCapacity(lpRect,16)
                ,dllCall("User32.dll\GetClientRect", "Ptr",hRootWnd, "Ptr",&lpRect)
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
        ,numPut(nNewPos,lpsi,20,"Int") ;  nPos
        ,dllCall("User32.dll\SetScrollInfo", "Ptr",hRootWnd, "Int",nBar, "Ptr",&lpsi, "Int",true, "Int")
    }
    _onMouseWheel(wParam, _, Msg, hWnd)    {
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
        ,varSetCapacity(lpRect,16,0)
        ,dllCall("User32.dll\GetClientRect", "Ptr",hRootWnd, "Ptr",&lpRect)
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
                    if (bRet:=this._getHScrollBarInfo(hWnd, objsbi))    {
                        if !(objsbi.rgstate.0&STATE_SYSTEM_UNAVAILABLE)    {
                            loop % (wheelCount*3)
                                dllCall("User32.dll\PostMessage", "Ptr",hWnd, "UInt",pm.Msg, "UPtr",pm.wParam, "Ptr",pm.lParam)
                            return 0
                        }
                    }
                }
            }
            return
        }
        ;-----------------------------------
        switch (this._opt[hRootWnd].innerScrollOnFocus)
        {
            case true:          hCntl:=dllCall("User32.dll\GetFocus", "Ptr")
            default:            hCntl:=hWnd
        }
        if (hCntl)    {
            style:=this._getWindowStyle(hCntl)
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
                if (hCntl==hWnd && hCntl!==hRootWnd)    {
                    switch (pm.Msg)
                    {
                        case WM_VSCROLL:        bRet:=this._getVScrollBarInfo(hCntl, objsbi)
                        default:                bRet:=this._getHScrollBarInfo(hCntl, objsbi) ;  WM_HSCROLL
                    }
                    if (bRet)    {
                        if !(objsbi.rgstate.0&STATE_SYSTEM_UNAVAILABLE)    {
                            if (pm.Msg==WM_HSCROLL)    {
                                loop % (wheelCount*3)
                                    dllCall("User32.dll\PostMessage", "Ptr",hCntl, "UInt",pm.Msg, "UPtr",pm.wParam, "Ptr",pm.lParam)
                                wheelCount:=0, ret:=0
                            }  else  {
                                wheelCount:=0, ret:=""
                            }
                        }
                    }
                }
            }  else  {
                hComboBoxWnd:=0
                switch (this._getClassName(hCntl))
                {
                    case "ComboBox":                hComboBoxWnd:=hCntl
                    case "Edit": ;  UpDown
                        if (hUpDownWnd:=this._isEditConnectedToUpDown(hCntl))    {
                            wheelCount:=0, ret:=0
                            ,pos32:=dllCall("User32.dll\SendMessage", "Ptr",hUpDownWnd, "UInt",UDM_GETPOS32, "UPtr",0, "Ptr",0)
                            ,dllCall("User32.dll\SendMessage", "Ptr",hUpDownWnd, "UInt",UDM_SETPOS32, "UPtr",0, "Ptr",pos32+wheelDistance//WHEEL_DELTA)
                            /*
                             About Up-Down Controls
                            https://learn.microsoft.com/en-us/windows/win32/controls/up-down-controls
                             Up-Down Control
                            https://learn.microsoft.com/en-us/windows/win32/controls/up-down-control-reference
                            */
                        }  else if (hComboBoxWnd:=this._isEditConnectedToComboBox(hCntl))    {
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
        loop % (wheelCount)
            dllCall("User32.dll\PostMessage", "Ptr",pm.hWnd, "UInt",pm.Msg, "UPtr",pm.wParam, "Ptr",pm.lParam)
        return ret
    }
    _onSizing(_*)    {
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
        ,varSetCapacity(lpsi,28,0)
        ,numPut(28,lpsi,0,"UInt")       ;  cbSize
        ,numPut(SIF_POS,lpsi,4,"UInt")  ;  fMask
        ,dllCall("User32.dll\GetScrollInfo", "Ptr",hRootWnd, "Int",SB_HORZ, "Ptr",&lpsi)
        ,nPosHorzPrev:=numGet(lpsi,20,"Int")
        ,varSetCapacity(lpsi,28,0)
        ,numPut(28,lpsi,0,"UInt")       ;  cbSize
        ,NumPut(SIF_POS,lpsi,4,"UInt")  ;  fMask
        ,dllCall("User32.dll\GetScrollInfo", "Ptr",hRootWnd, "Int",SB_VERT, "Ptr",&lpsi)
        ,nPosVertPrev:=numGet(lpsi,20,"Int")
        ;-----------------------------------
        ,varSetCapacity(lpRect,16,0)
        ,dllCall("User32.dll\GetClientRect", "Ptr",hRootWnd, "Ptr",&lpRect)
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
        ,varSetCapacity(lpsi,28,0)
        ,numPut(28,lpsi,0,"UInt"), numPut(SIF_PAGE|SIF_RANGE,lpsi,4,"UInt")
        ,nPage:=client.height
        ,nMax:=border.bottom-border.top-invisibility.hscroll
        if (this._getHScrollBarInfo(hRootWnd, objsbi))    {
            hscrollBarHeight:=objsbi.rcScrollBar.bottom-objsbi.rcScrollBar.top
            if (!invisibility.hscroll)
                nPage-=hscrollBarHeight, nMax-=hscrollBarHeight
            else if (!this._scrollInvisibilityFromState(objsbi.rgstate.0))
                nPage+=hscrollBarHeight
        }
        numPut(nPage,lpsi,16,"UInt")    ;  nPage
        ,numPut(nMax,lpsi,12,"Int")     ;  nMax
        ,dllCall("User32.dll\SetScrollInfo", "Ptr",hRootWnd, "Int",SB_VERT, "Ptr",&lpsi, "Int",true)
        ;-----------------------------------
        ,varSetCapacity(lpsi,28,0)
        ,numPut(28,lpsi,0,"UInt"), numPut(SIF_PAGE|SIF_RANGE,lpsi,4,"UInt")
        ,nPage:=client.width
        ,nMax:=border.right-border.left-invisibility.vscroll
        if (this._getVScrollBarInfo(hRootWnd, objsbi))    {
            vscrollBarWidth:=objsbi.rcScrollBar.right-objsbi.rcScrollBar.left
            if (!invisibility.vscroll)
                nPage-=vscrollBarWidth, nMax-=vscrollBarWidth
            else if (!this._scrollInvisibilityFromState(objsbi.rgstate.0))
                nPage+=vscrollBarWidth
        }
        numPut(nPage,lpsi,16,"UInt")    ;  nPage
        ,numPut(nMax,lpsi,12,"Int")     ;  nMax
        ,dllCall("User32.dll\SetScrollInfo", "Ptr",hRootWnd, "Int",SB_HORZ, "Ptr",&lpsi, "Int",true)
        ;-----------------------------------       
        ,varSetCapacity(lpsi,28,0)
        ,numPut(28,lpsi,0,"UInt")       ;  cbSize
        ,NumPut(SIF_POS,lpsi,4,"UInt")  ;  fMask
        ,dllCall("User32.dll\GetScrollInfo", "Ptr",hRootWnd, "Int",SB_HORZ, "Ptr",&lpsi)
        ,nPosHorzCurr:=numGet(lpsi,20,"Int")
        ,varSetCapacity(lpsi,28,0)
        ,numPut(28,lpsi,0,"UInt")       ;  cbSize
        ,NumPut(SIF_POS,lpsi,4,"UInt")  ;  fMask
        ,dllCall("User32.dll\GetScrollInfo", "Ptr",hRootWnd, "Int",SB_VERT, "Ptr",&lpsi)
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
    _onExitSizeMove(_1, _2, _3, hWnd)    {
        if (hWnd==this._hRootWnd)
            dllCall("User32.dll\SetFocus", "Ptr",0, "Ptr")
    }
    ;--------------------------------------------------
    _getHScrollBarInfo(hWnd, byRef objsbi)    {
        static OBJID_HSCROLL:=0xFFFFFFFA
        return this._getScrollBarInfo(hWnd,OBJID_HSCROLL,objsbi)
    }
    _getVScrollBarInfo(hWnd, byRef objsbi)     {
        static OBJID_VSCROLL:=0xFFFFFFFB
        return this._getScrollBarInfo(hWnd,OBJID_VSCROLL,objsbi)
    }
    _scrollInvisibilityFromState(rgstate:=0)    {
        static STATE_SYSTEM_INVISIBLE:=0x00008000
        return !!(rgstate&STATE_SYSTEM_INVISIBLE)
    }
    _getScrollBarInfo(hWnd, idObject, byRef objsbi)    {
        objsbi:={cbSize:"",rcScrollBar:{left:"",top:"",right:"",bottom:""},dxyLineButton:"",xyThumbTop:"",xyThumbBottom:"",reserved:"",rgstate:{0:"",1:"",2:"",3:"",4:"",5:""}}
        ,varSetCapacity(psbi,60,0)
        ,numPut(60,psbi,0,"UInt")
        if (bRet:=dllCall("User32.dll\GetScrollBarInfo", "Ptr",hWnd, "Int",idObject, "Ptr",&psbi))    {
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
    _resolveHwnd(hWnd)    {
        return format("{:d}",hWnd)&0xffffffff
    }
    _isWindow(hWnd)    {
        return dllCall("User32.dll\IsWindow", "Ptr",hWnd, "Int")
    }
    _getWindowStyle(hWnd)    {
        static GWL_STYLE:=-16
        return dllCall("User32.dll\GetWindowLong" (A_PtrSize==8?"Ptr":""), "Ptr",hWnd, "Int",GWL_STYLE, (A_PtrSize==8?"Ptr":"Int"))
    }
    _getClassName(hWnd, nMaxCount:="")    {
        static MAX_CLASS_NAME:=1024
        if (nMaxCount=="")
            nMaxCount:=MAX_CLASS_NAME
        varSetCapacity(lpClassName, (A_IsUnicode?2:1)*nMaxCount, 0)
        return (dllCall("User32.dll\GetClassName", "Ptr",hWnd, "Ptr",&lpClassName, "Int",nMaxCount, "Int"))
            ?strGet(&lpClassName)
            :""
    }
    _isEditConnectedToUpDown(hWnd)    {
        static GW_HWNDNEXT  := 2
            ,UPDOWN_CLASS   := "msctls_updown32"
        return (this._getClassName(hNextWnd:=dllCall("User32.dll\GetWindow", "Ptr",hWnd, "UInt",GW_HWNDNEXT))==UPDOWN_CLASS
            ?hNextWnd
            :0)
    }
    _isEditConnectedToComboBox(hWnd)    {
        static GA_PARENT    := 1
            ,WC_COMBOBOX    := "ComboBox"
        return (this._getClassName(hParentWnd:=dllCall("User32.dll\GetAncestor", "Ptr",hWnd, "UInt",GA_PARENT))==WC_COMBOBOX
            ?hParentWnd
            :0)
    }
    _getSystemMetrics(nIndex)    {
        return dllCall("User32.dll\GetSystemMetrics", "Int",nIndex, "Int")
    }
    ;--------------------------------------------------
    ;  C++ #define HIWORD(l) ((WORD)((((DWORD_PTR)(l)) >> 16) & 0xffff))
    _HIWORD(l)    {
        return (l<<32>>>48)
    }
    ;  C++ #define LOWORD(l) ((WORD)(((DWORD_PTR)(l)) & 0xffff))
    _LOWORD(l)    {
        return (l&0xffff) ;  (l<<48>>>48)
    }
    ;  C++ #define GET_WHEEL_DELTA_WPARAM(wParam) ((short)HIWORD(wParam))
    _GET_WHEEL_DELTA_WPARAM(wParam)    {
        return (wParam<<32>>48)
    }
    ;  C++ #define GET_KEYSTATE_WPARAM(wParam) (LOWORD(wParam))
    _GET_KEYSTATE_WPARAM(wParam)    {
        return (wParam&0xffff)
    }
}
