#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance Force
#Include <Class_ScrollableGui-ahk1>
ScrollableGui.init()
showGui()
F2::showGui()
F3::
    gui +LastFoundExist
    if (winExist())
        gui Destroy
    return
showGui()    {
    global hGuiWnd
    gui +LastFoundExist
    if (winExist())
        return
    prevIC := A_IsCritical
    critical On
    gui Font, Bold s16
    gui Add, Text,, % " The scrollbar appears automatically.`nThis occurs when the window is resized."
    gui Font, Norm s10
    gui Add, Edit, w480 r3 ReadOnly -Wrap, % "
    (LTrim0
    When the Edit control is focused, its scrollbar takes priority, functioning exclusively within the Edit area.
    This means that other scrollbars, like the one for the main window, will not respond while the Edit control is active.
    To scroll or manage the entire window, you first need to remove the focus from the Edit control.
    You can do this by clicking anywhere on the background of the window, outside the Edit control.
    Once the focus is removed, the main window's scrollbar will become active and available for use.
    This behavior has been carefully designed to include not only the Edit control but also ComboBox, DropDownList, and UpDown controls.
    )"
    gui Add, ComboBox, w480, Red||Green|Blue
    gui Add, DropDownList, w480, Black||White|Red
    gui Add, Edit, w480
    gui Add, UpDown, Range1-10, 5
    gui +HwndhGuiWnd +MaxSize +Resize
    gui Show, AutoSize, ScrollableGui Example 1
    ScrollableGui.register(hGuiWnd)
    critical % prevIC
}
guiClose(thisGui)    {
    gui Destroy
    return 0
}
