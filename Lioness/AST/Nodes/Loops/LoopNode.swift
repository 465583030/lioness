//
//  LoopNode.swift
//  Lioness
//
//  Created by Louis D'hauwe on 09/12/2016.
//  Copyright © 2016 - 2017 Silver Fox. All rights reserved.
//

import Foundation

public class LoopNode: ASTNode {
	
	public func compile(with ctx: BytecodeCompiler, in parent: ASTNode?) throws -> BytecodeBody {
		
		var bytecode = BytecodeBody()
		
		ctx.enterNewScope()
		
		
		let skipExitInstrLabel = ctx.nextIndexLabel()

		let exitLoopInstrLabel = ctx.nextIndexLabel()
		
		ctx.pushLoopHeader(exitLoopInstrLabel)
		
		
		let loopScopeStart = ctx.peekNextIndexLabel()
		
		let compiledLoop = try compileLoop(with: ctx, scopeStart: loopScopeStart)
		
		
		let loopEndLabel = ctx.peekNextIndexLabel()
		
		let skipExitInstruction = BytecodeInstruction(label: skipExitInstrLabel, type: .goto, arguments: [.index(loopScopeStart)], comment: "skip exit instruction")
		bytecode.append(skipExitInstruction)
		
		
		let exitLoopInstruction = BytecodeInstruction(label: exitLoopInstrLabel, type: .goto, arguments: [.index(loopEndLabel)], comment: "exit loop")
		bytecode.append(exitLoopInstruction)
		
		
		bytecode.append(contentsOf: compiledLoop)
		
		ctx.popLoopHeader()
		
		try ctx.leaveCurrentScope()
		
		return bytecode
	}
	
	public var childNodes: [ASTNode] {
		return []
	}
	
	func compileLoop(with ctx: BytecodeCompiler, scopeStart: Int) throws -> BytecodeBody {
		return []
	}
	
	public var description: String {
		return ""
	}
	
	public var nodeDescription: String? {
		return nil
	}
	
	public var descriptionChildNodes: [ASTChildNode] {
		return []
	}
	
}