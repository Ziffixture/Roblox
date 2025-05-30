--[[
Author     Ziffix (74087102)
Date       05/27/2025 (MM/DD/YYYY)
Version    1.0.4

Grassroots, case-insensitive Trie implementation.
]]



type Node = {
	word      : string,
	isWord    : boolean,
	character : string,

	parent   : Node,
	children : {Node},
}



local Trie          = {}
local TriePrototype = {}



local function getChild(parent: Node, character): Node?
	for _, child in parent.children do
		if child.character == character then
			return child
		end
	end

	return nil
end

local function getLastNode(parent: Node, word: string): (Node, {string}, depth)
	local characters = string.split(word, "")
	local node       = parent
	local depth      = 0

	for _, character in characters do
		local child = getChild(node, character)
		if not child then
			break
		end

		node  = child
		depth += 1
	end

	return node, depth, characters
end


function Trie.new(words: {string}?)
	local self = {}

	self.root          = {}
	self.root.children = {}

	setmetatable(self, TriePrototype)

	if words then
		for _, word in words do
			self:AddWord(word)
		end
	end

	return self
end

function TriePrototype:AddWord(word: string)
	local node, depth, characters = getLastNode(self.root, string.lower(word))

	for index = depth + 1, #characters do
		local child = {}

		child.character = characters[index]
		child.children  = {}
		child.parent    = node

		table.insert(node.children, child)

		node = child
	end

	node.word   = word
	node.isWord = true
end

function TriePrototype:RemoveWords(prefix: string)
	local node = getLastNode(self.root, string.lower(prefix))
	if node == self.root then
		return
	end

	local siblings = node.parent.children 
	local index    = table.find(siblings, node)

	table.remove(siblings, index)
end

function TriePrototype:GetWords(prefix: string?): {}
	prefix = prefix or ""
	
	local node, depth = getLastNode(self.root, string.lower(prefix))
	local words = {}
	
	if depth ~= #prefix then
		return words
	end

	local function getWords(parent: Node)
		if parent.isWord then
			table.insert(words, parent.word)
		end

		for _, child in parent.children do
			getWords(child)
		end
	end

	getWords(node)

	return words
end

function TriePrototype:__tostring()
	return table.concat(self:GetWords(), ", ")
end



TriePrototype.__index     = TriePrototype
TriePrototype.__metatable = "This metatable is locked."



return Trie
