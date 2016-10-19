//
//  Parser.swift
//  Lioness
//
//  Created by Louis D'hauwe on 04/10/2016.
//  Copyright © 2016 Silver Fox. All rights reserved.
//

import Foundation

public enum ParseError: Error {
	case unexpectedToken
	case undefinedOperator(String)
	
	case expectedCharacter(Character)
	case expectedExpression
	case expectedArgumentList
	case expectedFunctionName
	
	case internalInconsistencyOccurred

}

public class Parser {
	
	fileprivate let tokens: [Token]
	
	/// Token index
	fileprivate var index = 0
	
	public init(tokens: [Token]) {
		self.tokens = tokens
	}
	
	// MARK: -
	// MARK: Public
	
	public func parse() throws -> [ASTNode] {
		
		index = 0
		
		var nodes = [ASTNode]()
		
		while index < tokens.count {
			
			guard let currentToken = peekCurrentToken() else {
				throw ParseError.internalInconsistencyOccurred
			}
			
			switch currentToken {
				
				case .function:
					let node = try parseFunction()
					nodes.append(node)
				
				default:
					
					if shouldParseAssignment() {
						
						let assign = try parseAssignment()
						nodes.append(assign)
						
					} else {
						
						let expr = try parseExpression()
						nodes.append(expr)
					
					}
				
			}
			
		}
		
		return nodes
	}

	// MARK: -
	// MARK: Private
	
	fileprivate let operatorPrecedence: [String : Int] = [
		"+": 20,
		"-": 20,
		"*": 40,
		"/": 40,
		"^": 60
	]
	
	fileprivate func operatorString(for token: Token) -> String? {

		if case let Token.other(op) = token {
			return op
		}
		
		if case Token.comparatorEqual = token {
			return "=="
		}
		
		if case Token.notEqual = token {
			return "!="
		}
		
		if case Token.comparatorLessThan = token {
			return "<"
		}
		
		if case Token.comparatorLessThanEqual = token {
			return "<="
		}
		
		if case Token.comparatorGreaterThan = token {
			return ">"
		}
		
		if case Token.comparatorGreaterThanEqual = token {
			return ">="
		}
		
		return nil
	}
	
	fileprivate func operatorPrecedence(for token: Token) -> Int? {
		
		if case let Token.other(op) = token {
			return operatorPrecedence[op]
		}

		if case Token.comparatorEqual = token {
			return 10
		}
		
		if case Token.notEqual = token {
			return 10
		}
		
		if case Token.comparatorLessThan = token {
			return 10
		}
		
		if case Token.comparatorLessThanEqual = token {
			return 10
		}
		
		if case Token.comparatorGreaterThan = token {
			return 10
		}
		
		if case Token.comparatorGreaterThanEqual = token {
			return 10
		}
		
		return nil
	}
	
	fileprivate func booleanOperatorString(for token: Token) -> String? {
	
		if case Token.booleanOr = token {
			return "||"
		}
		
		if case Token.booleanAnd = token {
			return "&&"
		}
		
		if case Token.booleanNot = token {
			return "!"
		}
		
		if case Token.comparatorEqual = token {
			return "=="
		}
		
		if case Token.notEqual = token {
			return "!="
		}
		
		return nil
		
	}
	
	fileprivate func booleanOperatorPrecedence(for token: Token) -> Int? {
		
		if case Token.booleanOr = token {
			return 20
		}
		
		if case Token.booleanAnd = token {
			return 40
		}
		
		if case Token.booleanNot = token {
			return 60
		}
		
		if case Token.comparatorEqual = token {
			return 10
		}
		
		if case Token.notEqual = token {
			return 10
		}
		
		return nil
	}
	
	/// Get operator for token (e.g. '+=' returns '+')
	fileprivate func getOperator(for token: Token) -> String? {

		if case .shortHandAdd = token {
			return "+"
		}
		
		if case .shortHandSub = token {
			return "-"
		}
		
		if case .shortHandMul = token {
			return "*"
		}
		
		if case .shortHandDiv = token {
			return "/"
		}
		
		if case .shortHandPow = token {
			return "^"
		}

		return nil
	}

	// MARK: Tokens

	fileprivate func peekCurrentToken() -> Token? {
		return tokens[safe: index]
	}
	
	/// Look ahead 1 token
	fileprivate func peekNextToken() -> Token? {
		return peekToken(offset: 1)
	}
	
	/// Look ahead
	fileprivate func peekToken(offset: Int) -> Token? {
		return tokens[safe: index + offset]
	}
	
	@discardableResult
	fileprivate func popCurrentToken() -> Token {
		
		let t = tokens[index]
		index += 1
		
		return t
	}
	
	// MARK: Parsing
	
	/// Look ahead to check if boolean operator should be parsed
	fileprivate func shouldParseBooleanOp() -> Bool {

		var i = 0
		while let tokenAhead = peekToken(offset: i) {
			
			if case Token.true = tokenAhead {
				return true
			}
			
			if case Token.false = tokenAhead {
				return true
			}
			
			if let _ = booleanOperatorString(for: tokenAhead) {
				// Don't assume boolean op if op is also possible for binary ops
				if operatorPrecedence(for: tokenAhead) == nil {
					return true
				}
			}
			
			i += 1

			if case Token.parensClose = tokenAhead {
				continue
			}
			
			if case Token.parensOpen = tokenAhead {
				continue
			}
			
			return false
		}
		
		return false
		
	}

	/// Look ahead to check if assignment should be parsed
	fileprivate func shouldParseAssignment() -> Bool {

		guard let currentToken = peekCurrentToken(), case Token.identifier = currentToken else {
			return false
		}
		
		guard let nextToken = peekNextToken() else {
			return false
		}
		
		guard case Token.equals = nextToken else {
			return false
		}
		
		return true
		
	}
	
	fileprivate func parseAssignment() throws -> AssignmentNode {
		
		guard case let Token.identifier(variable) = popCurrentToken() else {
			throw ParseError.unexpectedToken
		}
		
		guard case Token.equals = popCurrentToken() else {
			throw ParseError.expectedCharacter("=")
		}
		
		let exp = try parseExpression()
		
		let assign = AssignmentNode(variable: VariableNode(name: variable), value: exp)

		return assign
	}
	
	fileprivate func parseNumber() throws -> ASTNode {
		
		guard case let Token.number(value) = popCurrentToken() else {
			throw ParseError.unexpectedToken
		}
		
		return NumberNode(value: value)
	}
	
	/// Expression can be a binary/bool op
	fileprivate func parseExpression() throws -> ASTNode {
		
		let node = try parsePrimary()
		
		// Handles short hand operators (e.g. "+=")
		if let currentToken = peekCurrentToken(), let op = getOperator(for: currentToken)  {
			
			popCurrentToken()

			let node1 = try parsePrimary()
			let expr = try parseBinaryOp(node1)
			
			guard let variable = node as? VariableNode else {
				throw ParseError.unexpectedToken
			}
			
			let operation = BinaryOpNode(op: op, lhs: variable, rhs: expr)
			
			let assignment = AssignmentNode(variable: variable, value: operation)
			
			return assignment
		
		}
		
		if shouldParseBooleanOp() {
			
			let expr = try parseBooleanOp(node)
			return expr
			
		}
		
		let expr = try parseBinaryOp(node)
		
		return expr

	}
	
	fileprivate func parseParens() throws -> ASTNode {
		
		guard case Token.parensOpen = popCurrentToken() else {
			throw ParseError.expectedCharacter("(")
		}
		
		let exp = try parseExpression()
		
		guard case Token.parensClose = popCurrentToken() else {
			throw ParseError.expectedCharacter(")")
		}
		
		return exp
	}
	
	fileprivate func parseNotOperation() throws -> ASTNode {
		
		guard case Token.booleanNot = popCurrentToken() else {
			throw ParseError.expectedCharacter("!")
		}
		
		guard let currentToken = peekCurrentToken() else {
			throw ParseError.unexpectedToken
		}
		
		if case Token.parensOpen = currentToken {
			
			let exp = try parseParens()
			
			return BooleanOpNode(op: "!", lhs: exp)
			
		} else {
			
			let lhs: ASTNode
			
			switch currentToken {
				
				case .identifier:
					lhs = try parseIdentifier()
				
				case .number:
					lhs = try parseNumber()
				
				case .true, .false:
					lhs = try parseRawBoolean()
				
				default:
					throw ParseError.unexpectedToken

			}
			
			return BooleanOpNode(op: "!", lhs: lhs)
			
		}

	}
	
	fileprivate func parseIdentifier() throws -> ASTNode {
		
		guard case let Token.identifier(name) = popCurrentToken() else {
			throw ParseError.unexpectedToken
		}

		guard let currentToken = peekCurrentToken(), case Token.parensOpen = currentToken else {
			return VariableNode(name: name)
		}
		
		popCurrentToken()
		
		var arguments = [ASTNode]()
		
		if let currentToken = peekCurrentToken(), case Token.parensClose = currentToken {
		
		} else {
			
			while true {
				
				let argument = try parseExpression()
				arguments.append(argument)

				if let currentToken = peekCurrentToken(), case Token.parensClose = currentToken {
					break
				}
				
				guard case Token.comma = popCurrentToken() else {
					throw ParseError.expectedArgumentList
				}
				
			}
			
		}
		
		popCurrentToken()
		return CallNode(callee: name, arguments: arguments)
	}
	
	/// Primary can be seen as the start of an operation 
	/// (e.g. boolean operation), where this function returns the first term
	fileprivate func parsePrimary() throws -> ASTNode {
		
		guard let currentToken = peekCurrentToken() else {
			throw ParseError.unexpectedToken
		}
		
		switch currentToken {
			case .identifier:
				return try parseIdentifier()
		
			case .number:
				return try parseNumber()

			case .true, .false:
				return try parseRawBoolean()

			case .booleanNot:
				return try parseNotOperation()
			
			case .parensOpen:
				return try parseParens()
			
			case .if:
				return try parseIfStatement()
			
			default:
				throw ParseError.expectedExpression
		}
		
	}
	
	fileprivate func parseIfStatement() throws -> ASTNode {
		
		guard case Token.if = popCurrentToken() else {
			throw ParseError.unexpectedToken
		}
		
		let condition = try parseExpression()
		
		guard case Token.curlyOpen = popCurrentToken() else {
			throw ParseError.expectedCharacter("{")
		}
		
		var body = [ASTNode]()
		
		while index < tokens.count {
			
			if shouldParseAssignment() {
				
				let assign = try parseAssignment()
				body.append(assign)
				
			} else {
				
				let expr = try parseExpression()
				body.append(expr)
				
			}
			
			if let currentToken = peekCurrentToken(), case Token.curlyClose = currentToken {
				break
			}
			
		}
		
		guard case Token.curlyClose = popCurrentToken() else {
			throw ParseError.expectedCharacter("}")
		}
		
		if let nextToken = peekCurrentToken(), case Token.else = nextToken {
			
			guard case Token.else = popCurrentToken() else {
				throw ParseError.unexpectedToken
			}
			
			guard case Token.curlyOpen = popCurrentToken() else {
				throw ParseError.expectedCharacter("{")
			}
			
			var elseBody = [ASTNode]()
			
			while index < tokens.count {
				
				if shouldParseAssignment() {
					
					let assign = try parseAssignment()
					elseBody.append(assign)
					
				} else {
					
					let expr = try parseExpression()
					elseBody.append(expr)
					
				}
				
				if let currentToken = peekCurrentToken(), case Token.curlyClose = currentToken {
					break
				}
				
			}
			
			guard case Token.curlyClose = popCurrentToken() else {
				throw ParseError.expectedCharacter("}")
			}

			return ConditionalStatementNode(condition: condition, body: body, elseBody: elseBody)

			
		} else {
			
			return ConditionalStatementNode(condition: condition, body: body)

		}
		
	}
	
	/// Parse "true" or "false"
	fileprivate func parseRawBoolean() throws -> ASTNode {
		
		guard let currentToken = peekCurrentToken() else {
			throw ParseError.unexpectedToken
		}
		
		if case Token.true = currentToken {
			popCurrentToken()
			return BooleanNode(bool: true)
		}
		
		if case Token.false = currentToken {
			popCurrentToken()
			return BooleanNode(bool: false)
		}
		
		throw ParseError.unexpectedToken
	}
	
	fileprivate func getCurrentTokenBinaryOpPrecedence() -> Int {
		
		guard index < tokens.count else {
			return -1
		}
		
		guard let currentToken = peekCurrentToken() else {
			return -1
		}
		
		guard let precedence = operatorPrecedence(for: currentToken) else {
			return -1
		}
		
		return precedence
	}
	
	fileprivate func getCurrentTokenBooleanOpPrecedence() -> Int {
		
		guard index < tokens.count else {
			return -1
		}
		
		guard let currentToken = peekCurrentToken() else {
			return -1
		}
		
		guard let precedence = booleanOperatorPrecedence(for: currentToken) else {
			return -1
		}
		
		return precedence
	}
	
	/// Recursive
	fileprivate func parseBinaryOp(_ node: ASTNode, exprPrecedence: Int = 0) throws -> ASTNode {
		
		var lhs = node
		
		while true {
			
			let tokenPrecedence = getCurrentTokenBinaryOpPrecedence()
			if tokenPrecedence < exprPrecedence {
				return lhs
			}
			
			guard let op = operatorString(for: popCurrentToken()) else {
				throw ParseError.unexpectedToken
			}
			
			var rhs = try parsePrimary()
			let nextPrecedence = getCurrentTokenBinaryOpPrecedence()
			
			if tokenPrecedence < nextPrecedence {
				rhs = try parseBinaryOp(rhs, exprPrecedence: tokenPrecedence + 1)
			}
			
			lhs = BinaryOpNode(op: op, lhs: lhs, rhs: rhs)
			
		}
		
	}
	
	fileprivate func parseBooleanOp(_ node: ASTNode, exprPrecedence: Int = 0) throws -> ASTNode {
		
		var lhs = node
		
		while true {
			
			let tokenPrecedence = getCurrentTokenBooleanOpPrecedence()
			if tokenPrecedence < exprPrecedence {
				
				return lhs
			}
			
			guard let op = booleanOperatorString(for: popCurrentToken()) else {
				throw ParseError.unexpectedToken
			}
			
			var rhs = try parsePrimary()
			let nextPrecedence = getCurrentTokenBooleanOpPrecedence()
			
			if tokenPrecedence < nextPrecedence {
				rhs = try parseBooleanOp(rhs, exprPrecedence: tokenPrecedence + 1)
			}
			
			lhs = BooleanOpNode(op: op, lhs: lhs, rhs: rhs)
			
		}
		
	}
	
	fileprivate func parsePrototype() throws -> PrototypeNode {
		
		guard case let Token.identifier(name) = popCurrentToken() else {
			throw ParseError.expectedFunctionName
		}
		
		guard case Token.parensOpen = popCurrentToken() else {
			throw ParseError.expectedCharacter("(")
		}
		
		var argumentNames = [String]()
		while let currentToken = peekCurrentToken(), case let Token.identifier(name) = currentToken {
			popCurrentToken()
			argumentNames.append(name)
			
			if let currentToken = peekCurrentToken(), case Token.parensClose = currentToken {
				break
			}
			
			guard case Token.comma = popCurrentToken() else {
				throw ParseError.expectedArgumentList
			}
		}
		
		// remove ")"
		popCurrentToken()
		
		guard case Token.curlyOpen = popCurrentToken() else {
			throw ParseError.expectedCharacter("{")
		}
		
		return PrototypeNode(name: name, argumentNames: argumentNames)
	}
	
	fileprivate func parseFunction() throws -> FunctionNode {
		
		popCurrentToken()
		
		let prototype = try parsePrototype()
		
		
		var body = [ASTNode]()

		while index < tokens.count {
			
			if shouldParseAssignment() {
				
				let assign = try parseAssignment()
				body.append(assign)
				
			} else {
				
				let expr = try parseExpression()
				body.append(expr)
				
			}
			
			if let currentToken = peekCurrentToken(), case Token.curlyClose = currentToken {
				break
			}
			
		}
		
		guard case Token.curlyClose = popCurrentToken() else {
			throw ParseError.expectedCharacter("}")
		}
		
		return FunctionNode(prototype: prototype, body: body)
	}

}
