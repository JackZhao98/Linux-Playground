
////////////////////////////
// File: SingleLineView.swift
// Description: 
//    This file contains an `SingleLineView` class. Low level view class.
//    It handles two different types of Terminal info:
//    user@host: ~/dir, and the user input and shell output
//    They are assigned to different appearance automatically.
// Last modified: May 16
/////////////////////////////
import SwiftUI
struct SingleLineView: View {
    let greenColor = Color.init(red: 136 / 255, green: 178 / 255, blue: 93 / 255)
    let whiteColor = Color.init(red: 241 / 255, green: 241 / 255, blue: 241 / 255)
    var green: String
    var black: String
    init (green: String = "", black: String = "") {
        self.green = green
        self.black = black
    }
    var body: some View {
        HStack {
            if self.green != "" {
                Text(self.green)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(greenColor)
                    .bold()
                Text(self.black)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(whiteColor)
            }
            else {
                Text(self.black)
                    .foregroundColor(whiteColor)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
}
