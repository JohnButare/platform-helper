;
; Microsoft Multimedia Keyboard
;

; Pause
ScrollLock::SendInput {Pause}

; Lock
*sc116::SendInput #l

; Messenger Key
*SC105::OpenIM()

; Documents, Pictures, Music
*SC14C::run "%UserDocuments%"
*SC164::run "%public%\Pictures"
*SC13C::run "%public%\Music"

; Ignore F Lock modifier for Microsoft Natural keyboard
*sc13B::SendInput {F1}
*sc108::SendInput {F2}
*sc107::SendInput {F3}
*sc13E::SendInput {F4}
*sc13F::SendInput {F5}
*sc140::SendInput {F6}
*sc141::SendInput {F7}
*sc142::SendInput {F8}
*sc143::SendInput {F9}
*sc123::SendInput {F10}
+sc123::SendInput +{F10}
*sc157::SendInput {F11}
*sc158::SendInput {F12}
*sc137::SendInput {Insert}

