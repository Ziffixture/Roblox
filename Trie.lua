--[[
Author     Ziffix (74087102)
Date       11/02/2024 (MM/DD/YYYY)
Version    1.0.0

Grassroots Trie implementation.
]]



type Container = {
	isWord    : boolean,
	parent    : Container,
	children  : {Container},
	character : string,
}



local Trie          = {}
local TriePrototype = {}



local function getChild(parent: Container, character): Container?
	for _, child in parent.children do
		if child.character == character then
			return child
		end
	end

	return nil
end

local function getLastContainer(parent: Container, word: string, breakpoint: number?): (Container, {string}, depth)
	local characters = string.split(word, "")
	local container  = parent
	local depth      = 0
	
	for index, character in characters do
		local child = getChild(container, character)
		if not child or breakpoint == index then
			break
		end
		
		container = child
		depth    += 1
	end
	
	return container, characters, depth
end


function Trie.new(words: {string})
	local self = {}
	
	self.root          = {}
	self.root.children = {}

	setmetatable(self, TriePrototype)

	for _, word in words do
		self:AddWord(word)
	end

	return self
end

function TriePrototype:AddWord(word: string)
	local container, characters, depth = getLastContainer(self.root, word)
	
	for index = depth + 1, #characters do
		local child = {}
		
		child.character = characters[index]
		child.children  = {}
		child.parent    = container
		
		table.insert(container.children, child)
		
		container = child
	end

	container.isWord = true
end

function TriePrototype:RemoveWords(prefix: string)
	local container = getLastContainer(self.root, word)
	if container == self.root then
		return
	end

	local siblings = container.parent.children 
	local index    = table.find(siblings, container)
	
	table.remove(siblings, index)
end

function TriePrototype:GetWords(prefix: string?): {}
	local container = if prefix	then getLastContainer(self.root, prefix) else self.root
	local words     = {}

	local function getWords(parent: {}, word): string
		word ..= parent.character
		
		if parent.isWord then
			table.insert(words, word)
		end
		
		for _, child in parent.children do
			getWords(child, word)
		end
	end
	
	for _, child in container.children do		
		getWords(child, "")
	end
	
	return words
end

function TriePrototype:__tostring()
	return table.concat(self:GetWords(), ", ")
end



TriePrototype.__index     = TriePrototype
TriePrototype.__metatable = "This metatable is locked."



return Trie
