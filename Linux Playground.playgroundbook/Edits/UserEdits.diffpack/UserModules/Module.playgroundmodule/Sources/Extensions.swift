////////////////////////////
// File: Extensions.swift
// Description: 
//     This file contains some extension funcs to better 
//     support this project. 
// Learned from: Apple Developer Forum, StackOverFlow
//
// Last modified: May 8
/////////////////////////////
import SwiftUI
extension Sequence {
    func sorted<Value>(
        on: KeyPath<Element, Value>,
        using: (Value, Value) -> Bool
    ) -> [Element] where Value: Comparable {
        return withoutActuallyEscaping(using, do: {using -> [Element] in
            return self.sorted(by: { using($0[keyPath: on], $1[keyPath: on]) })
        })
    }
}

extension View {
    func `if`<Content: View>(_ conditional: Bool, content: (Self) -> Content) -> TupleView<(Self?, Content?)> {
        if conditional {
            return TupleView((nil, content(self)))
        } else {
            return TupleView((self, nil))
        }
    }
}

struct TerminalTextField: View {
    var placeholder: Text
    @Binding var text: String
    var editingChanged: (Bool)->() = { _ in }
    var commit: ()->() = { }
    
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty { 
                placeholder.background(Color.gray)
            }
            TextField("", text: $text, onEditingChanged: editingChanged, onCommit: commit)
                .colorInvert()
                .foregroundColor(Color.init(red: 14 / 255, green: 14 / 255, blue: 14 / 255))
        }
    }
}
