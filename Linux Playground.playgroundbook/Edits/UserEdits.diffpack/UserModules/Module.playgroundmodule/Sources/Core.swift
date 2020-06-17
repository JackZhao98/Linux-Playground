////////////////////////////
// File: Core.swift
// Description: 
//    This file contains various low level classes and funcs
// - CommandLine: A simple struct object which stores 
//                user@host info, and a command I/O line.
// - Object: A simple struct, used by `Node`. 
//           Stores information like name, contents, permission.
// - Node: A struct, used by FileSystem. N-ary tree data structure.
//         Consider each folder is a node with various children, and
//         a file is just a node with no children. This class will handle
//         FileSystem Object in a low level.
//         No error handling, may return Optional object.
// Last modified: May 12
/////////////////////////////
import SwiftUI
import PlaygroundSupport

public func Start() {
    PlaygroundPage.current.setLiveView(TerminalView())
    // Set live view to be `TerminalView` object
    PlaygroundPage.current.wantsFullScreenLiveView.toggle()
    // Force user to enable full screen
}

public func Exit() {
    PlaygroundPage.current.finishExecution()
}

struct CommandLine: Hashable, Identifiable {
    var id = UUID()
    var green = ""
    var black = ""
    init (green: String, black: String) {
        self.green = green
        self.black = black
        formatString()
    }
    mutating func formatString() {
        if self.green != "" && self.black != "" {
            self.green += " "
        }
    }
}

struct object {
    var name: String
    var content: String
    var permission: Int = 6
    init(name: String, content: String = "") {
        self.name = name
        self.content = content
        self.permission = 6
    }
}

class Node {
    var value: object
    var type: Character
    var children: [Node] = []
    weak var parent: Node?
    
    init (value: object, type: Character, isLink: Bool = false) {
        self.value = value
        self.type = type
        self.parent = self
        if type == "d" {
            self.dirSetUp()
        }
    }
    func getNode(name: String) -> Node? {
        for each in children {
            if each.value.name == name {
                return each
            }
        }
        return nil
    }
    func getDirectory(directory: String) -> Node? {
        if directory == "." {
            return self
        }
        if directory == ".." {
            return self.parent!
        }
        for each in children {
            if each.value.name == directory {
                return each
            }
        }
        return nil
    }
    
    func create(child: Node) {
        children.append(child)
        child.parent = self
    }
    private func dirSetUp() {
        let link1 = Node(value: object(name: "."), type: "l")
        let link2 = Node(value: object(name: ".."), type: "l")
        create(child: link1)
        create(child: link2)
    }
}


