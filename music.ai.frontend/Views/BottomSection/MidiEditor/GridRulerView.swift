// //
// //  GridRulerView.swift
// //  music.ai.frontend
// //
// //  Created by Ben Dreyer on 3/23/25.
// //

import SwiftUI

// Grid Ruler View for displaying bars, beats, and time divisions
struct GridRulerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: MidiEditorViewModel
    
    var midiClip: MidiClip?
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Background
                let backgroundRect = Path(CGRect(origin: .zero, size: size))
                context.fill(backgroundRect, with: .color(themeManager.tertiaryBackgroundColor))
                
                guard let clip = midiClip else { return }
                
                // Calculate constants for drawing
                let pixelsPerBeat = viewModel.pixelsPerBeat
                let beatsPerBar = viewModel.beatsPerBar
                let clipDurationInBeats = clip.duration
                let numberOfBars = Int(ceil(clipDurationInBeats / Double(beatsPerBar)))
                
                // Line heights - starting from bottom (size.height)
                let barLineHeight = size.height * 0.8
                let beatLineHeight = size.height * 0.6
                let divisionLineHeight = size.height * 0.4
                
                // Text placement
                let textY = 2
                
                // Colors
                let barLineColor = themeManager.gridLineColor.opacity(0.8)
                let beatLineColor = themeManager.gridLineColor.opacity(0.6)
                let divisionLineColor = themeManager.gridLineColor.opacity(0.4)
                let textColor = themeManager.primaryTextColor
                
                // Draw bar lines and numbers
                for barIndex in 0...numberOfBars {
                    let barPosition = Double(barIndex * beatsPerBar)
                    let x = CGFloat(barPosition) * pixelsPerBeat
                    
                    // Bar line - draw exactly at the x position
                    let barLinePath = Path { path in
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x, y: size.height - barLineHeight))
                    }
                    context.stroke(barLinePath, with: .color(barLineColor), lineWidth: 1.0)
                    
                    // Bar number
                    let barNum = barIndex + 1 // 1-based bar numbers
                    let textPosition = CGRect(x: Int(x) + 4, y: textY, width: 30, height: 14)
                    context.draw(Text("\(barNum)").font(.system(size: 10)).foregroundColor(textColor),
                               in: textPosition)
                    
                    // Draw beat lines within each bar
                    if barIndex < numberOfBars {
                        for beatIndex in 1..<beatsPerBar {
                            let beatPosition = barPosition + Double(beatIndex)
                            let beatX = CGFloat(beatPosition) * pixelsPerBeat
                            
                            // Beat line - draw exactly at the x position
                            let beatLinePath = Path { path in
                                path.move(to: CGPoint(x: beatX, y: size.height))
                                path.addLine(to: CGPoint(x: beatX, y: size.height - beatLineHeight))
                            }
                            context.stroke(beatLinePath, with: .color(beatLineColor), lineWidth: 0.8)
                        }
                        
                        // Draw finer divisions based on grid division
                        let divisionsPerBeat = viewModel.gridDivision.divisionsPerBeat
                        if divisionsPerBeat > 1 {
                            for beatIndex in 0..<beatsPerBar {
                                for divIndex in 1..<divisionsPerBeat {
                                    let divPosition = barPosition + Double(beatIndex) + Double(divIndex) / Double(divisionsPerBeat)
                                    let divX = CGFloat(divPosition) * pixelsPerBeat
                                    
                                    // Division line - draw exactly at the x position
                                    let divLinePath = Path { path in
                                        path.move(to: CGPoint(x: divX, y: size.height))
                                        path.addLine(to: CGPoint(x: divX, y: size.height - divisionLineHeight))
                                    }
                                    context.stroke(divLinePath, with: .color(divisionLineColor), lineWidth: 0.5)
                                }
                            }
                        }
                    }
                }
                
                // Draw bottom border to ensure alignment
                let bottomBorderPath = Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height - 0.5)) // Position at exactly half a pixel from bottom
                    path.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
                }
                context.stroke(bottomBorderPath, with: .color(themeManager.secondaryBorderColor), lineWidth: 1.0)
            }
        }
        .frame(width: midiClip.map { viewModel.calculateGridWidth(clipDuration: $0.duration) } ?? 600)
        .onChange(of: viewModel.horizontalZoomLevel) { _, _ in 
            // Force redraw when horizontal zoom changes
        }
        .onChange(of: viewModel.gridDivision) { _, _ in
            // Force redraw when grid divisions change
        }
    }
}
