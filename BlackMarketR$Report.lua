--[[
Author     Ziffixture (74087102)
Date       03/10/2026 (MM/DD/YYYY)
Version    1.0.0
]]



--!strict
local DEV_EX_RATE = 0.0038 -- As of 03/10/2026 (MM/DD/YYYY)



local function commas(number: number): string
    local result = string.format("%.2f", number)
    local added  = 0

    while true do
        result, added = string.gsub(result, "^(-?%d+)(%d%d%d)", "%1,%2")
        if added == 0 then
            break
        end
    end

    return result
end

local function getReport(selling: number, cost: number, per: number): string
    local fair_maket_cost  = selling * DEV_EX_RATE
    local fair_market_rate = per * DEV_EX_RATE

    local purchase_rate = cost / per
    local purchase_cost = selling * purchase_rate
    
    local sellerProfit   = purchase_cost - fair_maket_cost
    local sellerIncrease = math.round((purchase_cost / fair_maket_cost - 1) * 100)

    return string.format(
        "Purchase Cost: $%s | Fair Market Cost: $%s | Seller Profit: $%s | Increase: %d%% | Fair Market Rate: $%s",
        commas(purchase_cost),
        commas(fair_maket_cost),
        commas(sellerProfit),
        sellerIncrease,
        commas(fair_market_rate)
    )
end



print(getReport(--[[...]]))
