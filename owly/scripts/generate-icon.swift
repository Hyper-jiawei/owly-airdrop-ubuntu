#!/usr/bin/env swift

// Generates AppIcon.icns: a stylized owl with a "heart-shaped facial disc"
// — the iconic visual feature that real owls have — set against an indigo
// night-sky squircle. Hand-rolled with Core Graphics, no SF Symbol
// dependency, identical across macOS versions.
//
// The drawing is parameterized by an `OwlExpression` so the same character
// system can be reused at runtime for the menu bar's three-state icon
// (sleeping / open / alert).
//
// Run: swift scripts/generate-icon.swift
// Output: resources/AppIcon.icns

import AppKit
import Foundation

// MARK: - Expression
enum OwlExpression {
    case sleeping  // closed eyes (^^), Z drifting nearby — Owly is off-duty
    case open      // wide round eyes — Owly is on watch (idle mode)
    case alert     // wide eyes + radial starburst — strong mode, max alert
}

// MARK: - Color palette (App icon)
let bgGradientTop = NSColor(calibratedRed: 0.34, green: 0.22, blue: 0.62, alpha: 1.0)
let bgGradientBot = NSColor(calibratedRed: 0.10, green: 0.07, blue: 0.28, alpha: 1.0)
let bodyTop       = NSColor(calibratedRed: 0.97, green: 0.88, blue: 0.65, alpha: 1.0)
let bodyBot       = NSColor(calibratedRed: 0.80, green: 0.62, blue: 0.32, alpha: 1.0)
let faceDiscColor = NSColor(calibratedRed: 1.00, green: 0.96, blue: 0.83, alpha: 1.0)
let eyeWhite      = NSColor.white
let pupilColor    = NSColor(calibratedRed: 0.10, green: 0.07, blue: 0.20, alpha: 1.0)
let beakColor     = NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.18, alpha: 1.0)
let starburstColor = NSColor(calibratedRed: 0.98, green: 0.55, blue: 0.10, alpha: 1.0)  // saturated amber-orange for contrast against the cream face
let starColor     = NSColor.white

// MARK: - Layout (in 1024x1024 reference space)
let canvas: CGFloat = 1024
let cornerR: CGFloat = canvas * 0.225

// Owl center is shifted slightly down so ear tufts have headroom.
let owlCx: CGFloat = 512
let owlCy: CGFloat = 480
let headW: CGFloat = 660
let headH: CGFloat = 700

// Ears
let earBaseY: CGFloat = owlCy + 250
let earTipY:  CGFloat = owlCy + 415
let earOffsetX: CGFloat = 195
let earHalfWidth: CGFloat = 90

// Facial disc — two overlapping circles, classic cartoon-owl style.
// The overlap forms a soft "8" silhouette around the eyes; the cream
// color contrasts with the tan body to read as a clear face mask.
// Eyes sit at each circle's center.
let discR: CGFloat = 200
let discDX: CGFloat = 132            // half-distance between disc centers
                                      // (smaller → more overlap → tighter bridge)
let discY:  CGFloat = owlCy + 70     // shared vertical center of the two circles

// Eyes — concentric in each facial disc
let eyeR: CGFloat = 122
let eyeOffsetX: CGFloat = discDX

// Pupils, slightly converged inward (looking at you)
let pupilR: CGFloat = 58
let pupilConvergeX: CGFloat = 22
let pupilNudgeY: CGFloat = -4

// Pupil highlight
let highlightR: CGFloat = 20
let highlightDX: CGFloat = 22
let highlightDY: CGFloat = 24

// Beak — pokes out from below the facial-disc circles, pointing down
let beakTopY: CGFloat = discY - discR + 35       // a hair inside the disc bottom
let beakTipY: CGFloat = beakTopY - 110
let beakHalfWidth: CGFloat = 36

// Starburst rays — emanate from each eye outward, breaking through the
// facial disc edge into the head feathers so they read as "this eye is
// glowing / on full alert" rather than tick marks on a clock face.
// Spike shape: narrow at the eye-edge, widens as it shoots outward.
let rayInner: CGFloat = eyeR + 12          // just outside the white eyeball
let rayOuter: CGFloat = eyeR + 130         // bursts past the facial-disc edge
let rayWidthInner: CGFloat = 4             // narrow at base
let rayWidthOuter: CGFloat = 26            // wide spike tip

// Z (sleeping decoration) — sits in the upper-right empty area
let zCenterX: CGFloat = owlCx + 290
let zCenterY: CGFloat = owlCy + 300
let zSize: CGFloat = 110
let zStroke: CGFloat = 24

// Background stars
let stars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (160, 820, 7, 0.65),
    (310, 900, 5, 0.45),
    (820, 870, 6, 0.55),
    (910, 760, 4, 0.40),
    (130, 560, 5, 0.45),
    (880, 480, 4, 0.40),
    (200, 200, 6, 0.55),
    (760, 220, 4, 0.40),
]

// MARK: - Output configuration
let projectRoot = FileManager.default.currentDirectoryPath as NSString
let iconsetDir: NSString = projectRoot.appendingPathComponent("build/AppIcon.iconset") as NSString
let outputIcns = projectRoot.appendingPathComponent("resources/AppIcon.icns")

let sizes: [(filename: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetDir as String)
try fm.createDirectory(atPath: iconsetDir as String, withIntermediateDirectories: true)

// MARK: - Drawing helpers

/// Returns the facial-disc path: two overlapping circles, one per eye.
/// Their union forms a soft "8" silhouette in cream against the tan body —
/// the classic cartoon-owl face mask.
func facialDiscPath(scale s: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    for sign: CGFloat in [-1, 1] {
        let cx = owlCx + sign * discDX
        let circle = NSBezierPath(ovalIn: NSRect(
            x: (cx - discR) * s,
            y: (discY - discR) * s,
            width: discR * 2 * s,
            height: discR * 2 * s
        ))
        path.append(circle)
    }
    return path
}

/// Draws starburst spikes around one eye. Each spike is a wedge that
/// tapers from narrow (at the eye edge) to wide (at the outer tip),
/// giving a "rays of light" feel rather than uniform ticks.
///
/// We draw 5 spikes per eye, only on the *outer* half (toward the side
/// of the face), to avoid the spikes from one eye colliding with the
/// other eye's spikes near the bridge of the beak.
func drawStarburst(rightSide: Bool, scale s: CGFloat) {
    let cx = owlCx + (rightSide ? 1 : -1) * eyeOffsetX
    let cy = discY + pupilNudgeY
    let center = NSPoint(x: cx * s, y: cy * s)

    // 4 spikes per eye, fanned only into the outer-side cone so they
    // don't hit the ear tufts (top), the beak (bottom), or the other
    // eye's spikes (inner). Angles are in "math degrees": 0° = +x,
    // 90° = +y (up).
    let outerAngles: [CGFloat]
    if rightSide {
        // Right eye: spikes shoot right and slightly up/down
        outerAngles = [-50, -15, 20, 55]    // SE, E-low, E-up, NE-low
    } else {
        // Left eye: mirror image
        outerAngles = [125, 160, 195, 230]  // NW-low, W-up, W-low, SW
    }

    starburstColor.setFill()
    for deg in outerAngles {
        let rad = deg * .pi / 180
        let dx = cos(rad)
        let dy = sin(rad)

        // Inner narrow base (close to eye)
        let baseHalf = rayWidthInner / 2
        let baseX = center.x + dx * rayInner * s
        let baseY = center.y + dy * rayInner * s
        let basePerpX = -dy * baseHalf * s
        let basePerpY = dx * baseHalf * s

        // Outer wide tip
        let tipHalf = rayWidthOuter / 2
        let tipX = center.x + dx * rayOuter * s
        let tipY = center.y + dy * rayOuter * s
        let tipPerpX = -dy * tipHalf * s
        let tipPerpY = dx * tipHalf * s

        let path = NSBezierPath()
        path.move(to: NSPoint(x: baseX + basePerpX, y: baseY + basePerpY))
        path.line(to: NSPoint(x: baseX - basePerpX, y: baseY - basePerpY))
        path.line(to: NSPoint(x: tipX - tipPerpX, y: tipY - tipPerpY))
        path.line(to: NSPoint(x: tipX + tipPerpX, y: tipY + tipPerpY))
        path.close()
        path.fill()
    }
}

/// Draws a "Z" glyph as three connected strokes.
func drawSleepZ(scale s: CGFloat) {
    let half = zSize / 2
    let topLeft  = NSPoint(x: (zCenterX - half) * s, y: (zCenterY + half) * s)
    let topRight = NSPoint(x: (zCenterX + half) * s, y: (zCenterY + half) * s)
    let botLeft  = NSPoint(x: (zCenterX - half) * s, y: (zCenterY - half) * s)
    let botRight = NSPoint(x: (zCenterX + half) * s, y: (zCenterY - half) * s)

    let path = NSBezierPath()
    path.lineWidth = zStroke * s
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.move(to: topLeft)
    path.line(to: topRight)
    path.line(to: botLeft)
    path.line(to: botRight)

    starburstColor.setStroke()
    path.stroke()
}

func renderIcon(pixels: Int, expression: OwlExpression) -> NSImage {
    let s = CGFloat(pixels) / canvas
    let pt: (CGFloat, CGFloat) -> NSPoint = { NSPoint(x: $0 * s, y: $1 * s) }

    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerR * s, yRadius: cornerR * s)

    NSGraphicsContext.current?.saveGraphicsState()
    bgPath.addClip()

    // 1. Background gradient
    NSGradient(starting: bgGradientTop, ending: bgGradientBot)!.draw(in: rect, angle: -90)

    // 2. Decorative stars (skip on tiny sizes)
    if pixels >= 64 {
        for (x, y, r, a) in stars {
            starColor.withAlphaComponent(a).setFill()
            NSBezierPath(ovalIn: NSRect(
                x: (x - r) * s, y: (y - r) * s,
                width: r * 2 * s, height: r * 2 * s
            )).fill()
        }
    }

    // 3. Ear tufts (drawn first so the head ellipse sits on top)
    bodyBot.setFill()
    for sign: CGFloat in [-1, 1] {
        let path = NSBezierPath()
        let cx = owlCx + sign * earOffsetX
        path.move(to: pt(cx - earHalfWidth, earBaseY))
        path.line(to: pt(cx + earHalfWidth, earBaseY))
        path.line(to: pt(cx, earTipY))
        path.close()
        path.fill()
    }

    // 4. Owl head/body — single ellipse with vertical gradient
    let headRect = NSRect(
        x: (owlCx - headW / 2) * s,
        y: (owlCy - headH / 2) * s,
        width: headW * s,
        height: headH * s
    )
    let headPath = NSBezierPath(ovalIn: headRect)

    NSGraphicsContext.current?.saveGraphicsState()
    headPath.addClip()
    NSGradient(starting: bodyTop, ending: bodyBot)!.draw(in: headRect, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // 5. Heart-shaped facial disc — two overlapping lighter circles
    if pixels >= 32 {
        faceDiscColor.setFill()
        facialDiscPath(scale: s).fill()
    }

    // 6. Starburst (alert) — drawn under the eyes so rays appear to radiate
    //    from behind them.
    if expression == .alert && pixels >= 64 {
        drawStarburst(rightSide: false, scale: s)
        drawStarburst(rightSide: true,  scale: s)
    }

    // 7. Eyes
    switch expression {
    case .open, .alert:
        // 7a. White eyeballs
        eyeWhite.setFill()
        for sign: CGFloat in [-1, 1] {
            let cx = owlCx + sign * eyeOffsetX
            NSBezierPath(ovalIn: NSRect(
                x: (cx - eyeR) * s, y: (discY - eyeR) * s,
                width: eyeR * 2 * s, height: eyeR * 2 * s
            )).fill()
        }
        // 7b. Pupils (converged inward)
        pupilColor.setFill()
        for sign: CGFloat in [-1, 1] {
            let pupilCx = owlCx + sign * (eyeOffsetX - pupilConvergeX)
            let pupilCy = discY + pupilNudgeY
            NSBezierPath(ovalIn: NSRect(
                x: (pupilCx - pupilR) * s, y: (pupilCy - pupilR) * s,
                width: pupilR * 2 * s, height: pupilR * 2 * s
            )).fill()
        }
        // 7c. Highlights
        if pixels >= 32 {
            eyeWhite.setFill()
            for sign: CGFloat in [-1, 1] {
                let pupilCx = owlCx + sign * (eyeOffsetX - pupilConvergeX)
                let pupilCy = discY + pupilNudgeY
                let hlCx = pupilCx + highlightDX
                let hlCy = pupilCy + highlightDY
                NSBezierPath(ovalIn: NSRect(
                    x: (hlCx - highlightR) * s, y: (hlCy - highlightR) * s,
                    width: highlightR * 2 * s, height: highlightR * 2 * s
                )).fill()
            }
        }

    case .sleeping:
        // Closed eyes — two downward arcs ("^^") rendered as bezier curves.
        // We use stroked arcs ~120° wide.
        pupilColor.setStroke()
        for sign: CGFloat in [-1, 1] {
            let cx = owlCx + sign * eyeOffsetX
            let cy = discY
            // Arc spanning from 200° to 340° (a smile shape), then we
            // flip it visually so it's "^" — by spanning -20° to 200°
            // instead. NSBezierPath's appendArc(withCenter:radius:startAngle:endAngle:)
            // expects degrees and draws CCW.
            let arc = NSBezierPath()
            arc.lineWidth = 22 * s
            arc.lineCapStyle = .round
            // Closed eye = downward-curving arc (wink). Center at eye
            // center, radius = eyeR * 0.7, span ~ 200° to 340° drawn
            // upside-down (so it's a "^").
            // Trick: draw the arc from 20° to 160° (top half) — that's "^".
            arc.appendArc(
                withCenter: NSPoint(x: cx * s, y: cy * s),
                radius: eyeR * 0.65 * s,
                startAngle: 20,
                endAngle: 160
            )
            arc.stroke()
        }
    }

    // 8. Beak — amber triangle pointing down, between the facial discs
    beakColor.setFill()
    let beakPath = NSBezierPath()
    beakPath.move(to: pt(owlCx - beakHalfWidth, beakTopY))
    beakPath.line(to: pt(owlCx + beakHalfWidth, beakTopY))
    beakPath.line(to: pt(owlCx, beakTipY))
    beakPath.close()
    beakPath.fill()

    // 9. Sleeping Z (decoration in the night sky)
    if expression == .sleeping && pixels >= 64 {
        drawSleepZ(scale: s)
    }

    NSGraphicsContext.current?.restoreGraphicsState()
    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to path: String) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "icon", code: 1)
    }
    try png.write(to: URL(fileURLWithPath: path))
}

// === The App icon shows Owly in `alert` state — wide eyes + starburst,
// the most "hero" form of the character. ===
let appIconExpression: OwlExpression = .alert

for (name, pixels) in sizes {
    let img = renderIcon(pixels: pixels, expression: appIconExpression)
    let path = iconsetDir.appendingPathComponent(name)
    try writePNG(img, to: path)
    print("  generated \(name) (\(pixels)x\(pixels))")
}

print("==> iconutil -c icns ...")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir as String, "-o", outputIcns]
try task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("✅ wrote \(outputIcns)")
} else {
    print("❌ iconutil failed (exit \(task.terminationStatus))")
    exit(1)
}

// Also export 512x512 previews of all 3 expressions to /tmp for easy review
let previewDir = "/tmp/owly-previews"
try? fm.removeItem(atPath: previewDir)
try? fm.createDirectory(atPath: previewDir, withIntermediateDirectories: true)
for expr in [OwlExpression.sleeping, .open, .alert] {
    let img = renderIcon(pixels: 512, expression: expr)
    let name: String
    switch expr {
    case .sleeping: name = "owl-sleeping.png"
    case .open:     name = "owl-open.png"
    case .alert:    name = "owl-alert.png"
    }
    let path = (previewDir as NSString).appendingPathComponent(name)
    try writePNG(img, to: path)
    print("  preview: \(path)")
}
