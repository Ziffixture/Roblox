--[[
Author     Ziffix (74087102)
Date       05/31/2025 (MM/DD/YYYY)
Version    1.0.1
]]



--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")


local Vendor  = ReplicatedStorage:WaitForChild("Vendor")
local Janitor = require(Vendor:WaitForChild("Janitor"))
local Trie    = require(Vendor:WaitForChild("Trie"))


local SUGGESTION_THRESHOLD = 3



local function mergeSearchSuggestion(input: string, suggestion: string?): string
	if not suggestion then
		return input
	end

	return input .. suggestion:sub(#input + 1)
end

local function makeTrie(searchContent: {GuiObject}): Trie.Trie
	local trie = Trie.new()
	
	for _, content in searchContent do
		trie:AddWord(content.Name)
	end
	
	return trie
end

local function Searchable(container: SearchContainer, getContent: () -> {GuiObject})
	local janitor = Maid.new()
	local trie    = makeTrie(getContent())
	
	local search         = container.Search
	local suggestion     = container.Suggestion
	local scrollingFrame = container.ScrollingFrame
	
	local suggested = nil

	local function whileFocused(callback: (...any) -> ())
		return function(...)
			if UserInputService:GetFocusedTextBox() == search then
				callback(...)
			end
		end
	end

	local function onTextChanged()
		local newText = search.ContentText
		local noInput = #newText == 0

		local searchOptions = trie:GetWords(newText)
		local searchContent = getContent()

		for _, content in searchContent do
			local isSuggested = table.find(searchOptions, content.Name) ~= nil

			content.Visible = isSuggested or noInput
		end

		suggested = searchOptions[1]

		search.Text        = newText:gsub("\t", "")
		suggestion.Text    = mergeSearchSuggestion(newText, suggested)
		suggestion.Visible = #newText >= SUGGESTION_THRESHOLD
	end

	local function onInputBegan(input: InputObject)
		if input.KeyCode ~= Enum.KeyCode.Tab then
			return
		end

		if not suggested then
			return
		end

		search.Text           = suggested
		search.CursorPosition = #suggested
	end

	local function onContentAdded(content: Instance)
		trie:AddWord(content.Name)
	end

	local function onContentRemoved(content: Instance)
		trie:RemoveWords(content.Name)
	end

	scrollingFrame.ChildAdded:Connect(onContentAdded)
	scrollingFrame.ChildRemoved:Connect(onContentRemoved)
	
	search:GetPropertyChangedSignal("Text"):Connect(whileFocused(onTextChanged))
	janitor:Add(UserInputService.InputBegan:Connect(whileFocused(onInputBegan))

	janitor:LinkToInstance(container)
end



export type SearchContainer = Frame & {
	Search         : TextBox,
	Suggestion     : TextLabel,
	ScrollingFrame : ScrollingFrame,
}


return Searchable
