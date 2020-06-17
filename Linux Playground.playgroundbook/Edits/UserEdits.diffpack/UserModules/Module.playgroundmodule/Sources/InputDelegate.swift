////////////////////////////
// File: InputDelegate.swift
// Description: 
//    This file contains an `InputDelegate` class. Supports error handling.
//    The class is able to handle arguments in two ways
//    1. Parse program name and argument, e.x. echo hello -> echo, hello
//    2. Parse program flags and optargs, and store in member variable.
//
// Simple Usage:
// let i = InputDelegate("program -opt arg")
//      i.program == "program"
//      i.arguments == "-opt arg"
// Then parser further for flags and optarg
// try i.getopt(validFlags: "al", maxArgs: 2)
//
// Last modified: May 12
/////////////////////////////

import Foundation

enum OPTERROR: Error {
    case TOOMANYARGS
    case TOOFEWARGS
    case INVALID
    case FATAL
}

// Class InputDelegate
// User input parser


class InputDelegate {
    var program: String = ""
    var arguments: String = ""
    
    var flags: [Character] = []
    var optarg: String = ""
    
    init (userInput: String = "") {
        (self.program, self.arguments) = InputHandler(input: userInput)
    }
    
    func getopt(validFlags: String = "", maxArgs: Int = 2) throws {
        try (self.flags, self.optarg) = self.optParser(argument: self.arguments, valid: validFlags, maxArgs: maxArgs)
    }
    
    private func InputHandler(input: String) -> (String, String) {
        var argv = input.components(separatedBy: " ")
        for v in argv {
            if v == "" {
                argv.remove(at: argv.firstIndex(of: v)!)
            }
        }
        let argc = argv.count
        var command: String = ""
        var argument: String = ""
        
        if (argc == 0) {
            return (command, argument)
        }
        command = argv[0]
        argv.remove(at: 0)
        
        for v in argv {
            argument += "\(v) "
        }
        if !argument.isEmpty {
            argument.removeLast()
        }
        return (command, argument)
        
    }
    
    private func optParser(argument: String, valid: String = "", maxArgs: Int) throws -> ([Character], String) {
        var argv = argument.components(separatedBy: " ")
        for v in argv {
            if v == "" {
                argv.remove(at: argv.firstIndex(of: v)!)
            }
        }
        let argc = argv.count
        
        if argc > maxArgs {
            throw  OPTERROR.TOOMANYARGS
        }
        if argc == 0 {
            return ([], "")
        }
        
        var optarg: String = ""
        var flags: [Character] = []
        
        
        // ONE ARGUMENT
        if argc == 1 {
            // Case 1: Flags only
            if argv[0].first == "-" || argv[0].first == "+" {
                for f in argv[0] {
                    flags.append(f)
                }
            }
                // Case 2: optarg only
            else {
                optarg = argv[0]
            }
        }
            // TWO ARGUMENT
        else if argc == 2 {
            if argv[0].first != "-" && argv[0].first != "+" {
                throw OPTERROR.INVALID
            }
            for f in argv[0] {
                flags.append(f)
            }
            optarg = argv[1]
        }
        else {
            throw OPTERROR.FATAL
        }
        
        if valid.count != 0 {
            for v in flags {
                if !valid.contains(v) {
                    throw OPTERROR.INVALID
                }
            }
        }
        return (flags, optarg)
    }
}
