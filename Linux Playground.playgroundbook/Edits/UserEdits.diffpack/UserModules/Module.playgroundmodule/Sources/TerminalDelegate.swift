////////////////////////////
// File: TerminalDelegate.swift
// Description: 
//    This file contains an `NTerminalDelegate` class. Top level class.
//    It handles all user input and shell output accordingly.
//    Supports error handling, TextView selecting.
// Last modified: May 16
/////////////////////////////

import SwiftUI
import Foundation
import PlaygroundSupport

class NTerminalDelegate: ObservableObject {
    @Published var displayedContents: [CommandLine] = []
    var TState: TerminalFSM = TerminalFSM.USERNAME
    var ConfirmCounter = 0
    private let supportedShellPrograms = [
        "cat", "cd", "chmod", "clear", "echo",
        "ls", "mkdir", "whoami", "passwd",
        "pwd", "rm", "touch", "help", "hint", "exit"]
    private let usage = [
        "cat": "[file ...]  Capture file contents",
        "cd":"[path ...]  Change Directory, for example: `cd Task0` or `cd Task0/t0`",
        "chmod":"[+rwx] [-rwx] [directory or file ...]  Change permission of an object",
        "clear":"no arguments, clear screen",
        "echo":"[string ...] Echoes back user input, for example: `echo hello` (will output: hello)",
        "ls":"[-al] [directory ...] List information about a directory. `ls -l` to view in list, `ls -a` view hidden files",
        "mkdir":"[directory_name] Creates a new directory, for example: `mkdir Task0`, or `mkdir Task0/t0`",
        "whoami":"display user id",
        "passwd":"change password",
        "pwd":"print full path to current directory",
        "rm":"[-rd] [directory/file ...] Remove files or folders. `rm -r` recursively remove. `rm -d` remove directory.",
        "touch":"[file ...] Creates a new file, for example: `touch Task0` or `touch Task0/t0`",
        "help":"[program name] `help` for full list",
        "hint":"Gives you important hint for every task. Read carefully :) *",
        "exit":"Securely terminate the program"
    ]
    private var execTable: Dictionary<String ,(String) throws ->()> = [:]
    
    private let sh: String = "LinuxPlayground"
    private var file: FileSystem = FileSystem()
    private var info: TerminalInfo = TerminalInfo()
    private var inputHandler: InputDelegate = InputDelegate()
    private var inBuffer: String = ""
    private var outBuffer: [String] = []
    private var tempPassword: String = ""
    private var currentTask: TaskFSM = TaskFSM.Task1
    
    init() {
        self.outBuffer = [
            "   __   _",
            "  / /  (_)__  __ ____ __",
            " / /__/ / _ \\/ // /\\ \\ /",
            "/____/_/_//_/\\_,_//_\\_\\",
            "  / _ \\/ /__ ___ _____ ________  __ _____  ___/ /",
            " / ___/ / _ `/ // / _ `/ __/ _ \\/ // / _ \\/ _  / ",
            "/_/  /_/\\_,_/\\_, /\\_, /_/  \\___/\\_,_/_//_/\\_,_/  ",
            "            /___//___/",
            "",
            "  *** IMPORTANT NOTES ***",
            "  INPUT:",
            "  The TextField in SwiftUI does not comply to the UIKit method `becomeFirstResponder()`",
            "  also I failed to create a Wrapped UIViewRepresentable custome UITextField to replace ",
            "  the current one that performs similarly.",
            "  If you CANNOT TYPE, that's completely NORMAL, click on the fake cursor everytime. Sorry.",
            "******************************************************************************************"
        ]
        self.refresh()
    }
    
    ///////////////////////
    //  Public Methods
    ///////////////////////
    
    // Public method
    // allows view class to send commands to TerminalDelegate to process.
    // @param: userInput as String
    func send(userInput: String) {
        self.inBuffer = userInput
        var greenInfo = ""
        var blackInfo = ""
        
        switch self.TState {
        case TerminalFSM.USERNAME:
            blackInfo = "Enter Username: "
            break
        case TerminalFSM.PASSWORD:
            blackInfo = "New password: "
            break
        case TerminalFSM.MATCH:
            blackInfo = "Current password: "
            break
        case TerminalFSM.CONFIRM:
            blackInfo = "Confirm password: "
            break
        case TerminalFSM.SHELL:
            greenInfo = "\(self.info.username)@\(self.info.hostname): \(self.getCurrentDirectory()) $"
            blackInfo = self.inBuffer
            break
        default:
            break
        }
        
        displayedContents.append(CommandLine(green: greenInfo, black: blackInfo))
        // Immediately process the user input
        //          self.refresh()
        self.terminalFSM()
        self.TasksDelegate()
        self.refresh()
    }
    
    
    func prompt () -> SingleLineView {
        var greenInfo = ""
        var blackInfo = ""
        
        switch self.TState {
        case TerminalFSM.USERNAME:
            blackInfo = "Enter Username:"
            break
        case TerminalFSM.PASSWORD:
            blackInfo = "New password:"
            break
        case TerminalFSM.MATCH:
            blackInfo = "Current password:"
            break
        case TerminalFSM.CONFIRM:
            blackInfo = "Confirm password:"
            break
        case TerminalFSM.SHELL:
            greenInfo = "\(self.info.username)@\(self.info.hostname): \(self.getCurrentDirectory()) $"
            break
        default:
            break
        }
        return SingleLineView(green: greenInfo, black: blackInfo)
    }
    
    func loads() {
        self.execTable = [
            "cat" : self.cat,
            "cd" : self.cd,
            "chmod" : self.chmod,
            "clear":self.clear,
            "echo" : self.echo,
            "ls" : self.ls,
            "mkdir" : self.mkdir,
            "whoami" : self.whoami,
            "passwd" : self.passwd,
            "pwd" : self.pwd,
            "rm" : self.rm,
            "touch" : self.touch,
            "help" : self.help,
            "hint" : self.hint,
            "exit":self.exit
        ]
    }
    
    ///////////////////////
    //  Private Methods
    ///////////////////////
    
    // Private method: process
    // It calls a function mapped to the desgnited program name.
    // handles the exception, then output some error message to the screen.
    private func process() {
        inputHandler = InputDelegate(userInput: self.inBuffer)
        let programName = inputHandler.program
        let arguments = inputHandler.arguments
        
        if (!self.supportedShellPrograms.contains(programName)) {
            self.outBuffer = ["\(self.sh): \"\(programName)\" is not supported. Use `help` to see a full list of supported commands."]
        }
        else {  // Assure the result is not nil because we have handled the `not supported` case
            
            let exec = self.execTable[programName]!
            
            do {
                
                try exec(arguments)
                
            } catch {
                
                // Handle errors.
                
                switch error {
                    
                case OPTERROR.TOOMANYARGS:
                    self.outBuffer=["\(programName): \(arguments): Too many arguments"]
                    self.outBuffer.append("If you were using flags like -a -b, please use -ab instead")
                    break
                case OPTERROR.TOOFEWARGS:
                    self.outBuffer=["\(programName): \(arguments): Too few arguments"]
                    self.outBuffer.append("If you were using file redirection like: `echo hi>a` please use `echo hi > a` instead")
                    break
                case OPTERROR.INVALID:
                    self.outBuffer=["\(programName): illegal option: \(arguments)"]
                    break
                case OPTERROR.FATAL:
                    self.outBuffer=["Fatal error."]
                    break
                case FileSystemErrors.noSuchFile:
                    self.outBuffer=["\(programName): \(arguments): No such file. "]
                    self.outBuffer.append("Trying to look for a file in other directory? Check your path. Use `ls` to see what is in your current folder.")
                    break
                case FileSystemErrors.noSuchDirectory:
                    self.outBuffer=["\(programName): \(arguments): No such directory"]
                    self.outBuffer.append("Trying to look for a folder in other directory? Check your path. Use `ls` to see what is in your current folder.")
                    break
                case FileSystemErrors.permissionDenied:
                    self.outBuffer=["\(programName): \(arguments): Permission denied"]
                    self.outBuffer.append("   hint: use `ls -l` to see what permission it has, then use `chmod +rwx FILE` to give it permission")
                    break
                case FileSystemErrors.notFile:
                    self.outBuffer=["\(programName): \(arguments): Not a file."]
                    break
                case FileSystemErrors.notDirectory:
                    self.outBuffer=["\(programName): \(arguments): Not a directory."]
                    self.outBuffer.append("   hint: Target object is a file, you can't use `cd`, `ls` to it.")
                    break
                case FileSystemErrors.isDirectory:
                    self.outBuffer=["\(programName): \(arguments): Is a directory."]
                    self.outBuffer.append("   hint: Trying to delete a folder? Add a -d option! `rm -d FOLDER`")
                    break
                case FileSystemErrors.isNotEmpty:
                    self.outBuffer=["\(programName): \(arguments): Directory not empty."]
                    self.outBuffer.append("   hint: Trying to remove? Add a -r option! `rm -r FOLDER`")
                    break
                case FileSystemErrors.badArgument:
                    self.outBuffer=["\(programName): \(arguments): invalid or unsupported arguments."]
                    break
                case FileSystemErrors.requireArgument:
                    self.outBuffer=["\(programName): \(arguments): requires an argument."]
                    break
                case FileSystemErrors.removeLink:
                    self.outBuffer=["\(programName): \".\" and \"..\" may not be removed"]
                    self.outBuffer.append("   hint: These are links. Try remove something else.`")
                    break
                case FileSystemErrors.existed:
                    self.outBuffer=["\(programName): \(arguments): file or directory exists"]
                    self.outBuffer.append("   hint: Change a name, or `rm` the existing one. Don't forget `rm -d` if removing directories.")
                    break
                default:
                    break
                }
                self.outBuffer.append("usage: \(programName): \(usage[programName]!)")
            }
        }
        
        // Update display contents buffer
        self.refresh()
    }
    
    
    private func terminalFSM() {
        switch TState {
        case TerminalFSM.USERNAME:
            self.setUsername()
            self.disclaimer()
            TState = TerminalFSM.SHELL
            break
        case TerminalFSM.MATCH:
            if (self.inBuffer != self.info.password) {
                self.outBuffer = ["passwd: password does not match (default: root)"]
                self.TState = TerminalFSM.SHELL
            }
            else {
                self.TState = TerminalFSM.PASSWORD
            }
            //              self.refresh()
            break
        case TerminalFSM.PASSWORD:
            self.tempPassword = self.inBuffer
            self.TState = TerminalFSM.CONFIRM
            break
        case TerminalFSM.CONFIRM:
            if (validatePassword()) {
                if (self.tempPassword.count < 6) {
                    self.tempPassword = ""
                    self.outBuffer = ["passwd: password too simple. At least 6 characters (type: `passwd`)"]
                } else {
                    self.info.password = self.tempPassword
                }
            } else {
                self.outBuffer = ["passwd: password does not match, try again. (type: `passwd`)"]
            }
            self.TState = TerminalFSM.SHELL
            //              self.refresh()
            break
        case TerminalFSM.SHELL:
            self.process()
            break
        default:
            break
        }
        self.refresh()
    }
    
    private func setUsername () {
        self.info.username = self.inBuffer
    }
    
    private func setPassword() {
        self.info.password = self.inBuffer
    }
    
    // Password validator. Check if the temppassword is the same as user input
    private func validatePassword() -> Bool {
        let confirmed = (self.inBuffer == self.tempPassword)
        return  confirmed
    }
    
    private func cat (arguments: String) throws {
        let ret = try file.cat(path: arguments)
        self.outBuffer.append(ret)
    }
    
    private func cd (arguments: String) throws {
        try inputHandler.getopt(validFlags: "", maxArgs: 1)
        try self.file.cd(path: inputHandler.optarg)
    }
    
    private func chmod (arguments: String) throws {
        var readable: Int = 0
        var writable: Int = 0
        var executable: Int = 0
        try inputHandler.getopt(validFlags: "-+rwx", maxArgs: 2)
        if (self.inputHandler.flags.count < 2 || self.inputHandler.optarg.isEmpty) {
            throw OPTERROR.TOOFEWARGS
        }
        var addPermission: Bool = false
        if (inputHandler.flags[0] != "+" && inputHandler.flags[0] != "-") {
            throw FileSystemErrors.badArgument
        }
        
        (readable, writable, executable) = try file.getmode(path: inputHandler.optarg)
        for f in self.inputHandler.flags {
            switch f {
            case "r":
                readable = (addPermission) ? 4 : 0
                break
            case "w":
                writable = (addPermission) ? 2 : 0
                break
            case "x":
                executable = (addPermission) ? 1 : 0
                break
            case "-":
                addPermission = false
                break
            case "+":
                addPermission = true
                break
            default:
                break
            }
        }
        try file.chmod(path: inputHandler.optarg, readable: (readable > 0) ? 1 : 0, writable: (writable > 0) ? 1 : 0, executable: executable & 1)
    }
    
    private func clear(arguments: String) throws {
        self.displayedContents.removeAll()
        self.refresh()
    }
    
    private func exit(arguments: String) {
        PlaygroundPage.current.finishExecution()
    }
    
    // Helper function.
    // It supports redirection from `echo` output
    // Parses a string and output three things: 
    //    Content, Target path, and isConcatanation mode.
    private func redirect(fullArguments: String, withQuote: Bool) throws -> (String, String, Bool){
        if withQuote {
            var buf = fullArguments
            let regex = "^\".*\" "
            let range = self.parseQuote(arguments: fullArguments, pattern: regex)!
            buf.removeSubrange(range)
            var content = String(fullArguments[range])
            let lists = buf.components(separatedBy: " ")
            if (lists.count < 2) {
                throw OPTERROR.TOOFEWARGS
            }
            if (lists.count > 2) {
                throw OPTERROR.TOOMANYARGS
            }
            if lists[0] != ">" && lists[0] !=  ">>" {
                throw OPTERROR.INVALID
            }
            content = String(content[self.parseQuote(arguments: content, pattern: "^\".*\"")!])
            content.removeFirst()
            content.removeLast()
            return (content, lists[1], lists[0] == ">>")
            
        } else {
            let lists = fullArguments.components(separatedBy: " ")
            if (lists.count < 3) {
                throw OPTERROR.TOOFEWARGS
            }
            if (lists.count > 3) {
                throw OPTERROR.TOOMANYARGS
            }
            if lists[1] != ">" && lists[1] !=  ">>" {
                throw OPTERROR.INVALID
            }
            return (lists[0], lists[2], lists[1] == ">>")
        }
        return ("", "", false)
    }
    
    // Helper function.
    // Uses a regex expression to determine if a double-quote wrapping exists.
    private func findQuote(arguments: String, pattern: String) -> Bool {
        let range = NSRange(location: 0, length: arguments.utf16.count)
        let regex = try! NSRegularExpression(pattern: pattern)
        let match = regex.firstMatch(in: arguments, options: [], range: range)
        return match != nil
    }
    
    // Helper function
    // Parse the content from double-quote
    private func parseQuote(arguments: String, pattern: String) -> Range<String.Index>? {
        guard let result = arguments.range(of: pattern, options: .regularExpression)
            else { return nil }
        return result
    }
    
    private func echo (arguments: String) throws {
        if (arguments == "") {
            self.outBuffer = [""]
            return
        } else if self.findQuote(arguments: arguments, pattern: "^\".*\"$") {
            var output = arguments
            output.removeFirst()
            output.removeLast()
            outBuffer = [output]
            return
        }
        if self.findQuote(arguments: arguments, pattern: "^\".*\" ") {
            let (content, target, appending) = try self.redirect(fullArguments: arguments, withQuote: true)
            try file.write(path: target, content: content, appending: appending)
        }
        else if arguments.components(separatedBy: " ").count == 3 && arguments.components(separatedBy: " ")[1].contains(">") {
            let (content, target, appending) = try self.redirect(fullArguments: arguments, withQuote: false)
            try file.write(path: target, content: content, appending: appending)
        }
        else {
            self.outBuffer = [arguments]
        }
    }
    
    private func ls (arguments: String)  throws {
        try inputHandler.getopt(validFlags: "-al", maxArgs: 2)
        var viewAll: Bool = false
        var list: Bool = false
        for f in inputHandler.flags {
            switch f {
            case "a":
                viewAll = true
                break
            case "l":
                list = true
                break
            default:
                break
            }
        }
        var ret = try file.ls(path: self.inputHandler.optarg, list: list, showHidden: viewAll)
        if (ret.count == 1 && ret[0] == "") {
            ret = []
        }
        self.outBuffer = ret
    }
    
    private func mkdir (arguments: String) throws {
        if arguments  == "" {
            throw FileSystemErrors.badArgument
        }
        try inputHandler.getopt(validFlags: "", maxArgs: 1)
        try file.mkdir(path: inputHandler.optarg)
    }
    
    private func whoami (arguments: String) throws {
        self.outBuffer = [self.info.username]
    }
    
    private func passwd (arguments: String) throws {
        if (self.info.password == "") {
            self.TState = TerminalFSM.PASSWORD
        }
        else {
            self.TState = TerminalFSM.MATCH
        }
    }
    
    private func pwd (arguments: String) throws {
        self.outBuffer = [file.pwd()]
    }
    
    private func rm (arguments: String) throws {
        try inputHandler.getopt(validFlags: "-rd", maxArgs: 2)
        var removeDir: Bool = false
        var recursive: Bool = false
        for f in inputHandler.flags {
            switch f {
            case "r":
                recursive = true
                break
            case "d":
                removeDir = true
                break
            default:
                break
            }
        }
        try file.rm(path: inputHandler.optarg, directory: removeDir, recursive: recursive)
    }
    
    private func touch (arguments: String) throws {
        try inputHandler.getopt(validFlags: "", maxArgs: 1)
        try file.touch(path: inputHandler.optarg)
    }
    
    private func help (arguments: String) throws {
        if (arguments.isEmpty) {
            for (program, prompt) in self.usage.sorted(by: { $0.key < $1.key }) {
                self.outBuffer.append("\(program)\t--\t\(prompt)")
            }
            self.outBuffer.append("")
            self.outBuffer.append("Note: programs ended with * is designed for \(self.sh) exclusively.")
            self.outBuffer.append("You will not see them anywhere else.")
            
            return
        }
        if (self.supportedShellPrograms.contains(arguments)) {
            self.outBuffer = ["\(arguments)\t--\t\(usage[arguments]!)"]
        }
        else {
            self.outBuffer = ["help: \"\(arguments)\" is not a valid/supported program, use `help` to see a list of support commands."]
        }
    }
    
    
    // Task Function -- Hint
    // 
    // Called by `process()`
    // It returns the correct Task hints and messages to `self.outBuffer`
    // cases controlled by a member task state counter: self.currentTask
    private func hint (arguments: String) throws {
        var message: [String] = []
        switch self.currentTask {
        case .Task1:
            message.append("Congratulations, you just used your first command line `hint`, but that's not a real Linux program unfortunately")
            message.append("Here's your real task:")
            message.append("Task 1: Can't Hack me now")
            message.append("Your were assigned a password `root` by default. But it is really easy to be compromised.")
            message.append("Change it! Use `help` to find which command can be used for \"Changing user password\" :)")
            break
        case .Task2:
            message.removeAll()
            message.append("`ls`, `pwd` and `cd`")
            message.append("In Linux Terminal, everything is command line based, no icons, no mouses :(")
            message.append("")
            message.append("The command `ls` will list all visible objects in your \"current directory\", ")
            message.append("For example: `ls` or `ls FolderName`")
            message.append("Use `pwd` to print working directory, or find it on the left side with other user info")
            message.append("Use `cd` (change directory) to move around. For example: \"cd Folder\" or \"cd folder1/folder2\"")
            message.append("You should notice your `current working directory` has changed if succuess.")
            message.append("   p.s. There are two special \"directories\" in every folder: . and ..")
            message.append("        They are links. \".\" links to current folder, while \"..\"links to parent folder. Use them just like a directory!")
            message.append("        for example, to move to parent folder: `cd ..`")
            message.append("")
            message.append("Play around with commands: `ls`, `pwd`, and `cd` introduced above :)")
            message.append("Note: You could always use `help ls` or `help` with other program name to learn the syntax.")
            message.append("")
            message.append("Task 2: Day One without your MOUSE")
            message.append("A new folder named `Task2` was just created. There is another folder inside. \"Try `cd` to that folder!\"")
            message.append("hint: use `ls Task2` to see objects inside the folder, you'll see a folder  `ThisOne`. Then use `cd Task2/ThisOne`!")
            break
        case .Task3:
            message.removeAll()
            message.append("-l and -a flags")
            message.append("Many Linux commands support option flags, that will run the program in a specific way")
            message.append("\(self.sh) also supports a few options. You could find the supported options in `help`")
            message.append("For `ls`, \(self.sh) supports `-l` and `-a`")
            message.append("   -a: View all objects, including hidden ones (objects whose name starts with a `.` are hidden objects)")
            message.append("   -l: View in a list. This will should more information about an object")
            message.append("   For example: \"drw-rw-rw- root folder\"")
            message.append("   the first character `d` stands for directory. If it is `-`, the object is a file")
            message.append("")
            message.append("Task 2.1: You Really Think You Are \".Hidden\"?")
            message.append("As you can see, many objects have been created. Use `ls -al` to find and `cd` into the hidden folder!")
            message.append("hint: use `ls -al` to view all. Find the only \"d\" type object, it should have a name started with a dot.")
            message.append("      Then `cd FOLDER_NAME` to move to that hidden folder!")
            break
        case .Task4:
            message.removeAll()
            if getCurrentDirectory() != "~/" {
                message.append("Move back to home directory first! Use `cd`, or `cd ../../..")
            }
            else {
                message.append("Create files and folders")
                message.append("You aren't able to right click then \"new file\" or \"new folder\" in Linux")
                message.append("Instead, we can use `mkdir` to make directory and `touch` to create a new file")
                message.append("Use `help mkdir` and `help touch` to find more!")
                message.append("")
                message.append("Task 3: Be a \"CREATOR\"")
                message.append("Your goal is to create a folder named \"Task3\", then create a file named \"Playground\"inside that folder.")
                message.append("hint: After you create a folder with `mkdir Task3`, either run the command with a relative path like: ")
                message.append("      `touch Task3/Playground`, or simply `cd Task3` to the folder then `touch Playground`!")
            }
            break
        case .Task5:
            message.removeAll()
            message.append("File Read and Write")
            message.append("A file without content is meaningless, in most cases.")
            message.append("READ: `cat` is one of the commands you want to use to \"capture\" the file contents")
            message.append("")
            message.append("Before learning how to write, we are learning another interesting command: `echo`.")
            message.append("With `echo [some string], it will \"echo\" back anything you write follows.")
            message.append("e.x. `echo \"hello\"`, output: hello")
            message.append("WRITE: Normally, you could use a text editor to write in Linux.")
            message.append("       but there is another way is also used a lot: redirection")
            message.append("       \">\" is the output redirection operator, use \">\" to overwrite and \">>\" to append")
            message.append("       > >> redirection will create a file if file does not exist")
            message.append("       usage: echo \"hello, world\" > file")
            message.append("Note: Redirection only works with `echo` in this \(self.sh), it's a lot powerful in real Linux environemnt") 
            message.append("")
            message.append("Task 4: You Can Read files, \"Write\"?")
            message.append("Get contents from ~/Task3/Playground (yes, I just modified it) and write into a file: ~/Task3/Task4.")
            message.append("hint: Use `cat ~/Task3/Playground` to read the message, and `echo \"THAT MESSAGE\" > ~/Task3/Task4`  to write!")
            break
            
        case .Task6:
            message.removeAll()
            message.append("Permission")
            message.append("Similar to MacOS and other OS, files and folders in Linux have three kind of permissions:")
            message.append("  read - The Read permission refers to a user’s capability to read the contents of the file.")
            message.append("  write – The Write permissions refer to a user’s capability to write or modify a file or directory.")
            message.append("  execute – The Execute permission affects a user’s capability to execute a file or view the contents of a directory.")
            message.append("")
            message.append("Remember the output from `ls -l`? rwx represents the three permissions.")
            message.append("There are three groups of permissions: owner, groups, all users. That's why you see three sets of \"rwx\" in `ls -l`")
            message.append("To simplify, we only have one permission group. ")
            message.append("The command `chmod`, aka Change Mode, can change the READ, WRITE, EXECUTE permission of an object.")
            message.append("    It takes options - [Add: +rwx | Remove:  -rwx].")
            message.append("    For example: `chmod +x-r file` will add EXECUTE and remove READ permission from \"file\"")
            message.append("")
            message.append("Remove")
            message.append("To remove an object, use command `rm FILE`.")
            message.append("   When removing a directory, you will need [-d] option")
            message.append("   When removing a non-empty directory, you will need [-r] option to remove RECURSIVELY")
            message.append("")
            message.append("Final Task: TOP SECRET - Access Granted")
            message.append("There is a folder named `TopSecret` in your home directory. Look inside, and remove an object named `evidence`")
            message.append("hint: Don't forget to use `ls -al` to view objects with their permission. Look at permission list for \"TopSecret\"")
            message.append("      `chmod` with [+rwx] can add permission, [-rwx] can remove permission. rm -rd [DIR] to remove a non-empty folder!")
            message.append("Feeling stuck? Try `chmod -r ~/TopSecret`, then `rm -rd ~/TopSecret/evidence`")
            break
        default:
            break
        }
        self.outBuffer = message
        self.refresh()
    }
    
    // Task Delegate.
    // It automatically detects if user has finished the prompted correctly.
    // Moves to the next state if current condition has been fulfilled.
    // Calls `TaskInitializer()` if needed.
    
    private func TasksDelegate() {
        var message: [String] = []
        switch self.currentTask {
        case .Task1:
            if self.info.password != "root" {
                message = ["Good job! You now have your own password. Moving forward to Task2..."]
                message.append("Use `hint` to see Task2 prompts!")
                TaskInitializer()
                self.currentTask = .Task2
            }
            break
        case .Task2:
            if getCurrentDirectory() == "~/Task2/ThisOne" {
                TaskInitializer()
                self.outBuffer = ["Wow, you found the directory. Don't hit me if I do this...", 
                                  "Move onto Task 2.1...Use `hint` to view more."]
                self.refresh()
                self.currentTask = .Task3
            }
            break
        case .Task3:
            if getCurrentDirectory() == "~/Task2/ThisOne/.Swift" {
                self.outBuffer = ["That's great! You are inside a hidden folder now."]
                self.outBuffer.append("Use command `cd` or `cd ../../..` to move back to your home directory, ")
                self.outBuffer.append("then use `hint` for the next move")
                self.refresh()
                self.currentTask = .Task4
            }
            break
        case .Task4:
            do {
                try file.cat(path: "~/Task3/Playground")
            } catch {
                do {
                    try file.rm(path: "~/Task3/Playground", directory: true)
                    self.outBuffer = ["Oops, you just created a directory named \"Playground\"."]
                    self.outBuffer.append("Use `touch` to create a file with that name!")
                    self.refresh()
                } catch {}
                break
            }
            do {
                try file.write(path: "~/Task3/Playground", content: "Think Different", appending: false)
            } catch {
                break
            }
            self.outBuffer = ["Nice. File \"~/Task3/Playground\" detected! Moving to Task 4. Use `hint` to proceed."]
            self.refresh()
            self.currentTask = .Task5
            break
        case .Task5:
            var new = ""
            do {
                new = try file.cat(path: "~/Task3/Task4")
            } catch {
                break
            }
            if (new == "Think Different") {
                self.outBuffer = ["You did great \"Jobs\"! Think Different. "]
                self.outBuffer.append("Moving to Task 5. Go back to home directory. Then use `hint` to proceed.")
                self.refresh()
                self.TaskInitializer()
                self.currentTask = .Task6
                
            }
            break
        case .Task6:
            do {
                try file.touch(path: "~/TopSecret/evidence/.try")
            } catch {
                self.outBuffer = ["Congratulations! You have finished all tasks! Hope you learned something about Linux :)"]
                self.outBuffer.append("Feel free to play around with other commands shown in `help`, or use `exit` to terminal the program.")
                self.outBuffer.append("This little App is powered by Apple's Swift Playgrounds  written in Swift 5.")
                self.outBuffer.append("Thank you for playing.")
                self.refresh()
                self.currentTask = .complete
            }
            do {
                try file.rm(path: "~/TopSecret/evidence/.try")
            } catch {}
            break
        default:
            break
        }
        self.outBuffer = message
        self.refresh()
    }
    
    // Initialize Task environment. It does create folder, modify permission, sort of stuff.
    private func TaskInitializer() {
        switch self.currentTask {
        case .Task1:
            // Initialize task2
            do {
                try file.mkdir(path: "./Task2")
                try file.mkdir(path: "./Task2/ThisOne")
            } catch {}
            break
        case .Task2: // Task 2.1
            var message: [String] = []
            do {
                for char in "abcdefghijklmnopqrstuvwxyz" {
                    if char == "j" {
                        try file.mkdir(path: "~/Task2/ThisOne/.Swift")
                    }
                    try file.touch(path: "~/Task2/ThisOne/\(char)")
                    
                    sleep(UInt32(0.3))
                    message.append("New file, or maybe folder? \"./\(char)\" has been created!")
                }
            } catch {}
            self.outBuffer = message
            self.refresh()
            break
            
        case .Task5:
            do {
                try file.mkdir(path: "~/TopSecret")
                try file.mkdir(path: "~/TopSecret/evidence")
                try file.touch(path: "~/TopSecret/evidence/file")
                try file.write(path: "~/TopSecret/iPhone12ProDesign", content: "Three cameras plus a LiDAR sensor. That's all I can tell.", appending: false)
                try file.chmod(path: "~/TopSecret", readable: 0, writable: 1, executable: 0)
            } catch {}
            break
        default:
            break 
        }
        
    }
    
    
    // Private: get cwd
    // @ return: a string type full path to cwd.
    private func getCurrentDirectory() -> String {
        return file.pwd()
    }
    
    // @param: single line of output, string
    // @returns a CommandLine object.
    private func generateCommandLine(output: String) -> CommandLine {
        let greenInfo = "\(self.info.username)@\(self.info.hostname): \(self.getCurrentDirectory()) $  "
        return CommandLine(green: greenInfo, black: output)
    }
    
    // Private: refresh
    // @ no param
    // @ no output
    // Place all contents in the output buffer
    // to display content list.
    private func refresh() {
        for buf in self.outBuffer {
            if (buf.isEmpty){
                displayedContents.append(CommandLine(green: "", black: ""))
                continue
            }
            displayedContents.append(CommandLine(green: "", black: buf))
        }
        self.outBuffer.removeAll()
    }
    
    private func disclaimer() {
        let messageOfDay = ["",
                            "******************************************************************************************",
                            "   Welcome to Linux Playground  \(self.info.username) ",
            //              "*******************************************************************************",
            " - Last Login: \(Date()) from Linux Playground",
            " - Author: Jack Zhao. All rights reserved © 2020",
            " - This is an interactive Linux learning environment powered by Swift.",
            " - The short journey will give you some basic ideas of Linux tools. Have fun 🍺",
            "","",
            "NOTE:",
            "This is a dumbed-down Linux simulator, some 'valid' operations in Linux are ",
            "not supported, for example: ",
            "`rm -r -f` does not work, use `rm -rf` instead",
            "file redirector `echo hello>a.txt` does not work, use `echo hello > a.txt` with space instead",
            "",
            " - To start your journey, enter `hint`, then hit enter"
        ]
        for each in messageOfDay {
            self.outBuffer.append(each)
        }
        self.refresh()
    }
}

enum TaskFSM {
    case Task1
    case Task2
    case Task3
    case Task4
    case Task5
    case Task6
    case complete
}

enum TerminalFSM {
    case USERNAME
    case PASSWORD
    case MATCH
    case CONFIRM
    case SHELL
}

struct TerminalInfo {
    var username: String = "username"
    var password: String = "root"
    var hostname: String = "localhost"
    init () {}
}
