import Quickshell.Io
import QtMultimedia
import QtQuick

Item {
  id: root
  property var shell: null
  property var onExit: null
  property string state: "title"
  property bool active: false
  property real sanity: 1.0
  property real survived: 0.0
  property int scares: 0
  property real posCamX: 6.5
  property real posCamZ: 6.5
  property real yaw: 0.0
  property real pitch: 0.0
  property real velX: 0.0
  property real velZ: 0.0
  property bool kForward: false
  property bool kBack: false
  property bool kLeft: false
  property bool kRight: false
  property bool kShift: false
  property real flicker: 1.0
  property real dark: 0.0
  property real scareAmt: 0.0
  property real shake: 0.0
  property real bobPhase: 0.0
  property int footIdx: 0
  property real lastMouseX: 0
  property real lastMouseY: 0
  property bool mouseReady: false
  property real ignoreUntil: 0
  property real nextEventAt: 12.0
  property real flickTimer: 0
  property bool flickActive: false
  property real darkTimer: 0
  property real darken: 0
  property bool startedOnce: false
  property string footWhich: "sounds/footstep1.wav"
  property int beatIdx: 0

  function fract(v) { return v - Math.floor(v) }
  function hash(x, y) {
    x = fract(x * 123.34)
    y = fract(y * 456.21)
    var d = x * (x + 45.32) + y * (y + 45.32)
    x += d; y += d
    return fract(x * y)
  }
  function pillarInfo(cx, cz) {
    var h = hash(cx, cz)
    if (h >= 0.55) return null
    var ox = (hash(cx + 7.13, cz + 7.13) - 0.5) * 6.0 * 0.18
    var oz = (hash(cx + 3.71, cz + 3.71) - 0.5) * 6.0 * 0.18
    return { x: (cx + 0.5) * 6.0 + ox, z: (cz + 0.5) * 6.0 + oz }
  }
  function wallInfo(cx, cz) {
    var h = hash(cx, cz)
    if (h <= 0.78) return null
    var ax = hash(cx + 11.37, cz + 11.37) > 0.5
    var cx0 = (cx + 0.5) * 6.0, cz0 = (cz + 0.5) * 6.0
    if (ax) return { cx: cx0, cz: cz0, hx: 0.14, hz: 3.0 }
    return { cx: cx0, cz: cz0, hx: 3.0, hz: 0.14 }
  }
  function resolveCircleAABB(px, pz, r, cx, cz, hx, hz) {
    var nx = Math.max(cx - hx, Math.min(px, cx + hx))
    var nz = Math.max(cz - hz, Math.min(pz, cz + hz))
    var dx = px - nx, dz = pz - nz
    var d2 = dx * dx + dz * dz
    if (d2 < r * r && d2 > 1e-8) {
      var d = Math.sqrt(d2)
      var overlap = r - d
      px += (dx / d) * overlap
      pz += (dz / d) * overlap
    }
    return { x: px, z: pz }
  }
  function collidePos(px, pz) {
    var r = 0.32
    var gid = Math.floor(px / 6.0), gjd = Math.floor(pz / 6.0)
    for (var di = -1; di <= 1; di++) {
      for (var dj = -1; dj <= 1; dj++) {
        var ci = gid + di, cj = gjd + dj
        var p = pillarInfo(ci, cj)
        if (p) {
          var res = resolveCircleAABB(px, pz, r, p.x, p.z, 0.62, 0.62)
          px = res.x; pz = res.z
        }
        var w = wallInfo(ci, cj)
        if (w) {
          var res2 = resolveCircleAABB(px, pz, r, w.cx, w.cz, w.hx, w.hz)
          px = res2.x; pz = res2.z
        }
      }
    }
    return { x: px, z: pz }
  }
  function findSpawn() {
    for (var ci = 0; ci < 20; ci++) {
      for (var cj = 0; cj < 20; cj++) {
        if (hash(ci, cj) < 0.55) continue
        var cx = (ci + 0.5) * 6.0, cz = (cj + 0.5) * 6.0
        var clear = true
        for (var di = -1; di <= 1 && clear; di++) {
          for (var dj = -1; dj <= 1 && clear; dj++) {
            var ni = ci + di, nj = cj + dj
            var nh = hash(ni, nj)
            if (nh < 0.55) {
              var ox = (hash(ni + 7.13, nj + 7.13) - 0.5) * 6.0 * 0.18
              var oz = (hash(ni + 3.71, nj + 3.71) - 0.5) * 6.0 * 0.18
              var px = (ni + 0.5) * 6.0 + ox, pz = (nj + 0.5) * 6.0 + oz
              var dx = cx - px, dz = cz - pz
              if (Math.sqrt(dx * dx + dz * dz) < 1.3) clear = false
            }
            if (nh > 0.78) {
              var ax = hash(ni + 11.37, nj + 11.37) > 0.5
              var wcx = (ni + 0.5) * 6.0, wcz = (nj + 0.5) * 6.0
              var whx = ax ? 0.14 : 3.0, whz = ax ? 3.0 : 0.14
              var cpx = Math.max(wcx - whx, Math.min(cx, wcx + whx))
              var cpz = Math.max(wcz - whz, Math.min(cz, wcz + whz))
              var ddx = cx - cpx, ddz = cz - cpz
              if (Math.sqrt(ddx * ddx + ddz * ddz) < 0.7) clear = false
            }
          }
        }
        if (clear) return { x: cx, z: cz }
      }
    }
    return { x: 21.0, z: 9.0 }
  }

  function startGame() {
    var sp = findSpawn()
    root.posCamX = sp.x; root.posCamZ = sp.z
    root.yaw = Math.random() * 6.28
    root.pitch = 0; root.velX = 0; root.velZ = 0
    root.sanity = 1.0; root.survived = 0; root.scares = 0
    root.flicker = 1.0; root.dark = 0; root.scareAmt = 0; root.shake = 0
    root.bobPhase = 0; root.darken = 0
    root.darkTimer = 0; root.flickTimer = 0; root.flickActive = false
    root.nextEventAt = 5 + Math.random() * 6
    root.state = "playing"
    enterSound.play()
    mDrone.play(); mBuzz.play()
  }

  function die() {
    root.state = "dead"
    deathSound.play()
    mDrone.pause(); mBuzz.pause()
  }

  function triggerScare() {
    root.scares++
    root.sanity = Math.max(0, root.sanity - 0.18)
    root.shake = 1.0
    scareAnimation.restart()
    stingSound.play()
    mDrone.audioOutput.volume = 0.12
  }

  function triggerFlicker() {
    root.flickActive = true
    root.flickTimer = 1.5 + Math.random() * 2.5
    switchSound.play()
  }

  function triggerDarkness() {
    root.darkTimer = 3.0 + Math.random() * 3.0
  }

  function triggerThud() { thudSound.play() }
  function triggerWhisper() { whisperSound.play() }

  function scheduleNext() {
    var base = root.survived > 180 ? 4 : root.survived > 60 ? 5 : 6
    root.nextEventAt = base + Math.random() * (base * 0.6)
  }

  function pickEvent() {
    var canScare = root.survived > 18
    var roll = Math.random()
    if (canScare && roll < 0.18) { triggerScare(); return }
    if (roll < 0.40) { triggerFlicker(); return }
    if (roll < 0.58) { triggerThud(); return }
    if (roll < 0.74) { triggerWhisper(); return }
    triggerDarkness()
  }

  function applyBob(dt) {
    var speed = Math.sqrt(root.velX * root.velX + root.velZ * root.velZ)
    if (speed > 0.5) {
      root.bobPhase += speed * dt * 2.6
      var prev = Math.sin(root.bobPhase - speed * dt * 2.6)
      var curr = Math.sin(root.bobPhase)
      if (prev > 0 && curr <= 0) {
        root.footIdx = (root.footIdx + 1) % 4
        root.footWhich = "sounds/footstep" + (root.footIdx + 1) + ".wav"
        footSound.source = root.footWhich
        footSound.play()
      }
    }
  }

  function tick() {
    if (!root.active || root.state !== "playing") return
    var dt = 0.016
    root.survived += dt

    var accel = root.kShift ? 8.0 : 5.0
    var damp = Math.exp(-8 * dt)
    var fw = root.kForward ? 1 : (root.kBack ? -1 : 0)
    var rt = root.kRight ? 1 : (root.kLeft ? -1 : 0)
    var sinY = Math.sin(root.yaw), cosY = Math.cos(root.yaw)
    var wfx = sinY, wfz = -cosY
    var rtx = cosY, rtz = sinY
    var wx = wfx * fw + rtx * rt
    var wz = wfz * fw + rtz * rt
    var wl = Math.sqrt(wx * wx + wz * wz)
    if (wl > 0) { wx /= wl; wz /= wl }
    root.velX = (root.velX + wx * accel * dt) * damp
    root.velZ = (root.velZ + wz * accel * dt) * damp
    var spd = Math.sqrt(root.velX * root.velX + root.velZ * root.velZ)
    var maxSpd = root.kShift ? 8.5 : 5.5
    if (spd > maxSpd) { root.velX *= maxSpd / spd; root.velZ *= maxSpd / spd }

    var nx = root.posCamX + root.velX * dt
    var nz = root.posCamZ + root.velZ * dt
    var c1 = collidePos(nx, root.posCamZ)
    var c2 = collidePos(c1.x, nz)
    root.posCamX = c2.x; root.posCamZ = c2.z

    applyBob(dt)

    root.flicker += (1.0 - root.flicker) * Math.min(1, dt * 8)
    if (root.flickActive) {
      root.flickTimer -= dt
      root.flicker = 0.05 + Math.random() * 0.8
      if (root.flickTimer <= 0) { root.flickActive = false; switchSound.play() }
    } else if (Math.random() < 0.008) {
      triggerFlicker()
    }

    var darkTarget = root.darkTimer > 0 ? 1.0 : 0.0
    if (root.darkTimer > 0) root.darkTimer -= dt
    root.darken += (darkTarget - root.darken) * Math.min(1, dt * 5)

    root.nextEventAt -= dt
    if (root.nextEventAt <= 0) { pickEvent(); scheduleNext() }

    var drain = 0.008 + 0.05 * root.darken + 0.015 * (root.flickActive ? 1 : 0)
    var regen = 0.004
    root.sanity = Math.max(0, Math.min(1, root.sanity - drain * dt + regen * dt))

    root.shake *= Math.exp(-6 * dt)
    if (root.shake < 0.005) root.shake = 0

    if (root.sanity <= 0) { die(); return }

    var camY = 1.62 + Math.sin(root.bobPhase) * 0.04
    if (spd > 0.5) camY += Math.sin(root.bobPhase * 2.03) * 0.012

    shader.uTime = root.survived
    shader.uCamX = root.posCamX; shader.uCamY = camY; shader.uCamZ = root.posCamZ
    shader.uYaw = root.yaw; shader.uPitch = root.pitch
    shader.uFlicker = root.flicker
    shader.uDark = root.darken
    shader.uScare = root.scareAmt
    shader.uShake = root.shake
    shader.uSanity = root.sanity

    mBuzz.audioOutput.volume = root.flickActive ? 0.18 : 0.04
    mDrone.audioOutput.volume = root.scareAmt > 0.01 ? 0.12 : 0.42

    if (root.sanity < 0.35) {
      if (beatTimer.interval !== 1050) beatTimer.interval = 1050
      beatTimer.running = true
    } else {
      beatTimer.running = false
    }
  }

  SoundEffect { id: stingSound; source: "sounds/sting.wav"; volume: 0.9 }
  SoundEffect { id: thudSound; source: "sounds/thud.wav"; volume: 0.65 }
  SoundEffect { id: whisperSound; source: "sounds/whisper.wav"; volume: 0.5 }
  SoundEffect { id: switchSound; source: "sounds/switch.wav"; volume: 0.45 }
  SoundEffect { id: footSound; source: "sounds/footstep1.wav"; volume: 0.38 }
  SoundEffect { id: enterSound; source: "sounds/enter.wav"; volume: 0.6 }
  SoundEffect { id: deathSound; source: "sounds/death.wav"; volume: 0.75 }
  SoundEffect { id: beatSound; source: "sounds/heartbeat.wav"; volume: 0.6 }

  MediaPlayer {
    id: mDrone
    source: "sounds/drone.wav"
    loops: MediaPlayer.Infinite
    audioOutput: AudioOutput { id: aoDrone; volume: 0.42 }
  }
  MediaPlayer {
    id: mBuzz
    source: "sounds/buzz.wav"
    loops: MediaPlayer.Infinite
    audioOutput: AudioOutput { id: aoBuzz; volume: 0.04 }
  }

  Timer { id: beatTimer; interval: 1050; repeat: true; running: false; onTriggered: beatSound.play() }

  SequentialAnimation {
    id: scareAnimation
    NumberAnimation { target: root; property: "scareAmt"; to: 1.0; duration: 90; easing.type: Easing.InQuad }
    NumberAnimation { target: root; property: "scareAmt"; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
    onFinished: { root.scareAmt = 0; mDrone.audioOutput.volume = 0.42 }
  }

  Timer {
    id: gameTick
    interval: 16; repeat: true
    running: root.active && root.state === "playing"
    onTriggered: root.tick()
  }

  function handleMouseMove(mx, my) {
    if (root.state !== "playing") return
    var now = Date.now()
    if (now < root.ignoreUntil) { root.lastMouseX = mx; root.lastMouseY = my; return }
    var dx = mx - root.lastMouseX
    var dy = my - root.lastMouseY
    root.lastMouseX = mx; root.lastMouseY = my
    if (Math.abs(dx) > 50 || Math.abs(dy) > 50) return
    root.yaw += dx * 0.004
    root.pitch = Math.max(-1.2, Math.min(1.2, root.pitch - dy * 0.004))
    var w = root.width || 1920, h = root.height || 1080
    var margin = 60
    if (mx < margin || mx > w - margin || my < margin || my > h - margin) {
      var ndx = Math.round(w / 2 - mx)
      var ndy = Math.round(h / 2 - my)
      recenterProc.command = [
        "bash", "-c",
        "read CX CY <<< \"$(hyprctl cursorpos | tr -d '(),')\" && hyprctl dispatch movecursor $((CX+" + ndx + ")) $((CY+" + ndy + "))"
      ]
      recenterProc.running = true
      root.ignoreUntil = now + 160
    }
  }

  Process {
    id: recenterProc
    command: ["true"]
  }

  ShaderEffect {
    id: shader
    anchors.fill: parent
    property real uResX: root.width || 1920
    property real uResY: root.height || 1080
    property real uTime: 0
    property real uFlicker: 1.0
    property real uCamX: 3.0
    property real uCamY: 1.62
    property real uCamZ: 3.0
    property real uYaw: 0.0
    property real uPitch: 0.0
    property real uDark: 0.0
    property real uScare: 0.0
    property real uShake: 0.0
    property real uSanity: 1.0
    fragmentShader: "shaders/backrooms.frag.qsb"
  }

  Item { id: keyCatcher; anchors.fill: parent; focus: true
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(e) {
      if (root.state === "title") { root.startGame(); e.accepted = true; return }
      if (root.state === "dead") { root.state = "title"; e.accepted = true; return }
      switch (e.key) {
        case Qt.Key_Escape: if (root.onExit) root.onExit(); e.accepted = true; break
        case Qt.Key_W: case Qt.Key_Up: root.kForward = true; e.accepted = true; break
        case Qt.Key_S: case Qt.Key_Down: root.kBack = true; e.accepted = true; break
        case Qt.Key_A: case Qt.Key_Left: root.kLeft = true; e.accepted = true; break
        case Qt.Key_D: case Qt.Key_Right: root.kRight = true; e.accepted = true; break
        case Qt.Key_Shift: root.kShift = true; e.accepted = true; break
        case Qt.Key_P:
          if (root.state === "playing") { root.state = "paused"; mDrone.pause(); mBuzz.pause(); e.accepted = true }
          else if (root.state === "paused") { root.state = "playing"; mDrone.play(); mBuzz.play(); e.accepted = true }
          break
      }
    }
    Keys.onReleased: function(e) {
      switch (e.key) {
        case Qt.Key_W: case Qt.Key_Up: root.kForward = false; break
        case Qt.Key_S: case Qt.Key_Down: root.kBack = false; break
        case Qt.Key_A: case Qt.Key_Left: root.kLeft = false; break
        case Qt.Key_D: case Qt.Key_Right: root.kRight = false; break
        case Qt.Key_Shift: root.kShift = false; break
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.BlankCursor
    onPositionChanged: function(mouse) { root.handleMouseMove(mouse.x, mouse.y) }
    onPressed: function(mouse) {
      keyCatcher.forceActiveFocus()
      if (mouse.button === Qt.RightButton) { if (root.onExit) root.onExit(); return }
      if (root.state === "title") root.startGame()
      else if (root.state === "dead") root.state = "title"
    }
  }

  onActiveChanged: {
    if (root.active) {
      keyCatcher.forceActiveFocus()
      root.lastMouseX = root.width / 2
      root.lastMouseY = root.height / 2
      root.mouseReady = true
      root.ignoreUntil = Date.now() + 300
    } else {
      root.kForward = false; root.kBack = false
      root.kLeft = false; root.kRight = false; root.kShift = false
      if (root.state === "playing") { root.state = "paused"; mDrone.pause(); mBuzz.pause() }
    }
  }

  function fmtTime(s) {
    var m = Math.floor(s / 60), sec = Math.floor(s % 60)
    return (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
  }

  Rectangle { anchors.fill: parent; color: "transparent"; visible: root.state === "title"

    Column { anchors.centerIn: parent; spacing: Math.max(8, Math.round(parent.height * 0.018))
      visible: root.state === "title"; opacity: root.state === "title" ? 1 : 0

      Text { text: "THE BACKROOMS"; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.075); font.bold: true; color: "#d8c66a"; anchors.horizontalCenter: parent.horizontalCenter }
      Text { text: "you clipped out of reality"; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.02); color: "#998855"; anchors.horizontalCenter: parent.horizontalCenter }
      Item { width: 1; height: Math.round(parent.parent.height * 0.02) }
      Text { text: "WASD  MOVE    MOUSE  LOOK    SHIFT  RUN    P  PAUSE    ESC  EXIT"; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.016); color: "#776644"; anchors.horizontalCenter: parent.horizontalCenter }
      Item { width: 1; height: Math.round(parent.parent.height * 0.01) }
      Text { text: "HEADPHONES RECOMMENDED"; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.014); color: "#885533"; anchors.horizontalCenter: parent.horizontalCenter }
      Text { text: "may contain flashing images and sudden loud sounds"; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.012); color: "#665533"; anchors.horizontalCenter: parent.horizontalCenter }
      Item { width: 1; height: Math.round(parent.parent.height * 0.025) }
      Text { text: "CLICK TO ENTER"; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.032); font.bold: true; color: "#d8c66a"; anchors.horizontalCenter: parent.horizontalCenter; opacity: 0.5 + 0.5 * Math.sin(Date.now() * 0.004); Behavior on opacity { NumberAnimation { duration: 100 } }
        Timer { interval: 16; repeat: true; running: root.state === "title"; onTriggered: parent.opacity = 0.5 + 0.5 * Math.sin(Date.now() * 0.004) }
      }
    }
  }

  Item { visible: root.state === "playing" || root.state === "paused"

    Column { anchors.top: parent.top; anchors.topMargin: Math.round(parent.height * 0.025); anchors.left: parent.left; anchors.leftMargin: Math.round(parent.width * 0.025); spacing: 4
      Text { text: "TIME " + fmtTime(root.survived); font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.018); color: "#aa9966"}
    }
    Column { anchors.top: parent.top; anchors.topMargin: Math.round(parent.height * 0.025); anchors.right: parent.right; anchors.rightMargin: Math.round(parent.width * 0.025); spacing: 4
      Text { text: "SCARES " + root.scares; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.018); color: "#aa6644"; anchors.right: parent.right }
    }
    Column { anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(parent.height * 0.035); anchors.left: parent.left; anchors.leftMargin: Math.round(parent.width * 0.025); spacing: 4
      Text { text: "SANITY"; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.013); color: "#996644"}
      Rectangle { width: 200; height: 6; radius: 3; color: "#1a1208"; border.color: "#332211"; border.width: 1
        Rectangle { width: parent.width * Math.max(0, root.sanity); height: parent.height; radius: parent.radius; color: root.sanity > 0.5 ? "#994422" : root.sanity > 0.25 ? "#cc4422" : "#ee3311"; Behavior on width { NumberAnimation { duration: 120 } } }
      }
    }
    Text { visible: root.state === "paused"; anchors.centerIn: parent; text: "PAUSED"; font.family: "monospace"; font.pixelSize: Math.round(parent.height * 0.05); color: "#ffffff"; opacity: 0.85 }
  }

  Column { visible: root.state === "dead"; anchors.centerIn: parent; spacing: Math.max(8, Math.round(parent.height * 0.022))
    Text { text: "YOU NEVER LEFT"; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.065); font.bold: true; color: "#cc3311"; anchors.horizontalCenter: parent.horizontalCenter}
    Item { width: 1; height: Math.round(parent.parent.height * 0.015) }
    Text { text: "survived " + fmtTime(root.survived); font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.022); color: "#aa8855"; anchors.horizontalCenter: parent.horizontalCenter}
    Text { text: root.scares + " scares witnessed"; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.018); color: "#886644"; anchors.horizontalCenter: parent.horizontalCenter}
    Item { width: 1; height: Math.round(parent.parent.height * 0.02) }
    Text { text: "CLICK TO WANDER AGAIN"; font.family: "monospace"; font.pixelSize: Math.round(parent.parent.height * 0.02); color: "#886644"; anchors.horizontalCenter: parent.horizontalCenter; opacity: 0.5 + 0.5 * Math.sin(Date.now() * 0.004)
      Timer { interval: 16; repeat: true; running: root.state === "dead"; onTriggered: parent.opacity = 0.5 + 0.5 * Math.sin(Date.now() * 0.004) }
    }
  }

  function debug() {
    return JSON.stringify({
      state: root.state, survived: Math.round(root.survived * 10) / 10,
      sanity: Math.round(root.sanity * 100), scares: root.scares,
      x: Math.round(root.posCamX * 10) / 10, z: Math.round(root.posCamZ * 10) / 10,
      yaw: Math.round(root.yaw * 100) / 100, pitch: Math.round(root.pitch * 100) / 100,
      flicker: Math.round(root.flicker * 100), dark: Math.round(root.darken * 100),
      shake: Math.round(root.shake * 100), w: Math.round(root.width), h: Math.round(root.height)
    })
  }
}
