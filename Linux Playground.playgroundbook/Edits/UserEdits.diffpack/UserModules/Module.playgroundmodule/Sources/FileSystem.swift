////////////////////////////
// File: FileSystem.swift
// Description: 
//    This file contains an `FileSystem` class. Supports error handling.
//    The class is able to simulate a UNIX file system. Supports various 
//    file operations, including: cd, rm, touch, mkdir, ls, cat, chmod, pwd
// Used by: NTerminalDelegate.
// It has serious error handling, works flawlessly.
//
// Last modified: May 14
/////////////////////////////


enum FileSystemErrors: Error {
    case noSuchFile
    case noSuchDirectory
    case permissionDenied
    case notFile
    case notDirectory
    case isDirectory
    case isNotEmpty
    case badArgument
    case requireArgument
    case removeLink
    case existed
}

class FileSystem {
    var root : Node = Node(value: object(name: "LinuxPlayGroundRoot"), type: "d")
    var currentNode : Node
    var currentWorkingDirectory = "~/"
    
    init () {
        self.currentNode = self.root
    }
    
    func rm(path: String, directory: Bool = false, recursive: Bool = false) throws {
        //rm: "." and ".." may not be removed
        let (path, target) = self.parsePathAndTarget(path: path)
        if target == "." || target == ".." {
            throw FileSystemErrors.removeLink
        }
        let tempNode: Node? = self.accessDirectory(paths: path.components(separatedBy: "/"))
        if tempNode == nil {
            throw FileSystemErrors.noSuchDirectory
        }
        if tempNode!.type == "f" {
            throw FileSystemErrors.notDirectory
        }
        for (i, child) in tempNode!.children.enumerated() {
            if child.value.name == target {
                if (child.type == "d" && directory) {
                    if child.children.count > 2 && !recursive {
                        throw FileSystemErrors.isNotEmpty
                    }
                    else {
                        tempNode!.children.remove(at: i)
                    }
                } else if child.type == "f" {
                    tempNode!.children.remove(at: i)
                }
                else {
                    throw FileSystemErrors.isDirectory
                }
                return
            }
        }
        throw FileSystemErrors.noSuchFile
    }
    
    func write(path: String, content: String, appending: Bool) throws {
        let (path, target) = self.parsePathAndTarget(path: path)
        var tempNode: Node? = self.accessDirectory(paths: path.components(separatedBy: "/"))
        if tempNode == nil {
            throw FileSystemErrors.noSuchDirectory
        }
        if tempNode?.type == "f" {
            throw FileSystemErrors.notDirectory
        }
        var create = tempNode?.getNode(name: target)
        if create == nil {
            (tempNode?.create(child: Node(value: object(name: target), type: "f")))!
            create = tempNode?.getNode(name: target)
        }
        if create!.type != "f" {
            throw FileSystemErrors.notFile
        }
        if !isWriteable(node: create!) {
            throw FileSystemErrors.permissionDenied
        }
        
        if appending {
            create?.value.content += content
        }
        else {
            create?.value.content = content
        }
    }
    
    func cat(path: String) throws -> String {
        var ret = ""
        let (path, target) = self.parsePathAndTarget(path: path)
        var tempNode: Node? = self.accessDirectory(paths: path.components(separatedBy: "/"))
        if tempNode == nil {
            throw FileSystemErrors.noSuchDirectory
        }
        if tempNode?.type == "f" {
            throw FileSystemErrors.notDirectory
        }
        tempNode = tempNode?.getNode(name: target)
        if tempNode == nil {
            throw FileSystemErrors.noSuchFile
        }
        if tempNode!.type != "f" {
            throw FileSystemErrors.notFile
        }
        if !isReadable(node: tempNode!) {
            throw FileSystemErrors.permissionDenied
        }
        else {
            ret = tempNode!.value.content
        }
        return ret
    }
    
    func getmode(path: String = "") throws -> (Int, Int, Int) {
        let (path, target) = self.parsePathAndTarget(path: path)
        var tempNode: Node? = self.accessDirectory(paths: path.components(separatedBy: "/"))
        tempNode = tempNode?.getNode(name: target)
        let permission = tempNode!.value.permission
        return (permission&4, permission&2, permission&1)
    }
    
    func chmod(path: String = "", readable: Int, writable: Int, executable: Int) throws {
        let (path, target) = self.parsePathAndTarget(path: path)
        var tempNode: Node? = self.accessDirectory(paths: path.components(separatedBy: "/"))
        tempNode = tempNode?.getNode(name: target)
        if tempNode == nil {
            throw FileSystemErrors.noSuchDirectory
        }
        tempNode?.value.permission = (readable * 4) | (writable * 2) | (executable *  1)
    }
    
    func ls(path: String = "", list: Bool = false, showHidden: Bool = false) throws -> [String] {
        var lookingAt = self.getFullPathTo(path: path)
        if path == "" {
            lookingAt = self.currentWorkingDirectory
        }
        let walker = self.accessDirectory(paths: lookingAt.components(separatedBy: "/"))
        var viewableFiles: [Node] = []
        
        // Check if node exists
        if walker == nil {
            throw FileSystemErrors.noSuchDirectory
        }
        
        // Check readability
        if !isReadable(node: walker!) {
            throw FileSystemErrors.permissionDenied
        }
        // Add children to output queue.
        for f in walker!.children {
            // If first char is ., hidden file.
            // Display only if showHidden flag is true
            if f.value.name.first == "." {
                if showHidden {
                    viewableFiles.append(f)
                } else {
                    continue
                }
            } else {
                viewableFiles.append(f)
            }
        }
        var ret: [String] = []
        var temp = ""
        viewableFiles = viewableFiles.sorted(on: \.value.name, using: <)
        for v in viewableFiles {
            if list {
                let permission = (isReadable(node: v) ? "r" : "-") + (isWriteable(node: v) ? "w" : "-") + (isExecutable(node: v) ? "x" : "-")
                ret.append("\((v.type == "f") ? "-" : "d")" + String(repeating: permission, count: 3) + "  root   \(v.value.name)")
                
            } else {
                temp += "\(v.value.name)  "
            }
        }
        if (!list) {
            ret = [temp]
        }
        return ret
    }
    
    func mkdir(path: String = "") throws {
        let (path, target) = self.parsePathAndTarget(path: path)
        let tempNode: Node? = self.accessDirectory(paths: path.components(separatedBy: "/"))
        if tempNode == nil {
            throw FileSystemErrors.noSuchDirectory
        }
        if tempNode?.type == "f" {
            throw FileSystemErrors.notDirectory
        }
        if !isWriteable(node: tempNode!) {
            throw FileSystemErrors.permissionDenied
        }
        for each in tempNode!.children {
            if target == each.value.name {
                throw FileSystemErrors.existed
            }
        }
        (tempNode?.create(child: Node(value: object(name: target), type: "d")))!
    }
    
    func touch(path: String = "") throws {
        let (path, target) = self.parsePathAndTarget(path: path)
        let tempNode: Node? = self.accessDirectory(paths: path.components(separatedBy: "/"))
        if tempNode == nil {
            throw FileSystemErrors.noSuchDirectory
        }
        if tempNode!.type == "f" {
            throw FileSystemErrors.notDirectory
        }
        if !isWriteable(node: tempNode!) {
            throw FileSystemErrors.permissionDenied
        }
        for each in tempNode!.children {
            if target == each.value.name {
                throw FileSystemErrors.existed
            }
        }
        (tempNode?.create(child: Node(value: object(name: target), type: "f")))!
    }
    
    func cd (path: String) throws {
        var path = path
        if path == "" {
            path = "~/"
        }
        let fullPath = self.getFullPathTo(path: path)
        print("full path: \(fullPath)")
        let paths = self.pathParser(paths: fullPath)
        let findNode = self.accessDirectory(paths: paths)
        if findNode == nil {
            throw FileSystemErrors.noSuchDirectory
        }
        if !isReadable(node: findNode!) {
            throw FileSystemErrors.permissionDenied
        }
        if (findNode?.type == "f") {
            throw FileSystemErrors.notDirectory
        }
        self.currentNode = findNode!
        self.currentWorkingDirectory = fullPath
    }
    
    func pwd() -> String {
        var pathList: [String] = []
        var walker: Node = self.currentNode
        while walker.value.name != "LinuxPlayGroundRoot" {
            pathList.insert(walker.value.name, at: 0)
            walker = walker.parent!
        }
        pathList.insert("~", at: 0)
        var ret = ""
        for p in pathList {
            ret += "\(p)/"
        }
        if pathList.count > 1 {
            ret.removeLast()
        }
        return ret
    }
    
    
    // Private funcs
    private  func join(dir1: String, dir2: String) -> String {
        let dir1List = pathParser(paths: dir1)
        let dir2List = pathParser(paths: dir2)
        let fullPath = dir1List + dir2List
        var ret = ""
        for path in fullPath {
            if path != "" {
                ret += "\(path)/"
            }
        }
        // Remove the additional /
        ret.removeLast()
        return ret
    }
    private func accessDirectory (paths: [String]) -> Node? {
        var walker: Node? = self.root
        for p in paths {
            //            print("p = \(p)")
            if p == "~" || p == "" {
                continue
            }
            walker = walker?.getDirectory(directory: p)
            if walker == nil {
                print("throw: no Such Directory: \(p)")
                return nil
            }
        }
        return walker
    }
    private func argumentParser (argument: String) -> [String] {
        let args = argument.components(separatedBy: " ")
        var ret: [String] = []
        for node in args {
            if node != "" {
                ret.append(node)
            }
        }
        return ret
    }
    private func pathParser(paths: String) -> [String] {
        // path sample : a/b/c, or /b/c/d
        let nodes = paths.components(separatedBy: "/")
        var ret: [String] = []
        for node in nodes {
            ret.append(node)
        }
        return ret
    }
    private func getFullPathTo(path: String) -> String {
        var full: String
        if path.first == "~" {
            full = path
        } else if path.first == "/" {
            full = self.join(dir1: "~", dir2: path)
        } else {
            full = self.join(dir1: self.currentWorkingDirectory, dir2: path)
        }
        return full
    }
    private func parsePathAndTarget(path: String) -> (String, String) {
        var paths = self.pathParser(paths: self.getFullPathTo(path: path))
        let target = paths.removeLast()
        var pathToTarget = ""
        for each in paths {
            pathToTarget += "\(each)/"
        }
        pathToTarget += "."
        return (pathToTarget, target)
    }
    private func isReadable(node: Node) -> Bool {
        return node.value.permission & 4 != 0
    }
    private func isWriteable(node: Node) -> Bool {
        return node.value.permission & 2 != 0
    }
    private func isExecutable(node: Node) -> Bool {
        return node.value.permission & 1 != 0
    }
    
}
