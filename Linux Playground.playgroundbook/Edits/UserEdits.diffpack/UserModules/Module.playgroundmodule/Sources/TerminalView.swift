////////////////////////////
// File: TerminalView.swift
// Description: 
//    This file contains an `TerminalView` class. 
//    This is the main View where PlaygroundPage.current.liveView runs
// Last modified: May 10
/////////////////////////////

import SwiftUI
import Combine
import PlaygroundSupport 

public struct TerminalView: View {
    @ObservedObject var termDelegate = NTerminalDelegate()
    @State var buffer: String = ""
    @State var frame: CGSize = CGSize(width: 400, height: 600)
    @State var focused: [Bool] = [true]
    let color = Color.init(red: 46 / 255, green: 48 / 255, blue: 56  / 255)
    
    public init() {
        self.termDelegate.loads()
    }
    public var body: some View {
        GeometryReader { geometry in
            
            ZStack {
                self.color
                ScrollView (showsIndicators: false) {
                    VStack {
                        ForEach(self.termDelegate.displayedContents, id: \.self) { each in
                            HStack {
                                SingleLineView(green: each.green, black: each.black).frame(height: 30)
                                Spacer()
                            }
                        }
                        HStack {
                            self.termDelegate.prompt()
                            TerminalTextField (
                                placeholder: Text(" "),
                                text: self.$buffer,
                                commit: {
                                    self.termDelegate.send(userInput: self.buffer)
                                    self.buffer = ""
                            })
                                .font(.system(.body, design: .monospaced))
                                .disableAutocorrection(true)
                                .padding(.leading, 3)
                        }.padding(.top, -9)
                        Spacer()
                    }
                    .padding(.bottom, 35)
                    .padding(.leading, 20)
                    .padding(.top, 35)
                    .rotationEffect(.degrees(180))
                }
                .rotationEffect(.degrees(180))
            }
            
        }
    }
}
