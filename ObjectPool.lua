--[[
Author     Ziffixture (74087102)
Date       08/19/2025 (MM/DD/YYYY)
Version    1.0.2
]]



type ObjectPool<T> = {
    active   : {T},
    inactive : {T},

    get      : (any) -> T,
    get_next : () -> T,

    recycle     : (T) -> (),
    recycle_all : () -> (),
}



local function object_pool<T>(prefab: T, on_recycle: (T) -> ()): T
    local pool = {} :: ObjectPool<T>
    pool.active   = {}
    pool.inactive = {}


    local function new(id: number): T
        local instance

        if #pool.inactive > 0 then
            instance = table.remove(pool.inactive)
        else
            instance = prefab:Clone()
        end

        pool.active[id] = instance

        return instance
    end

    local function recycle(id: number)
        local instance = pool.active[id]
        if not instance then
            warn("Attempt to recycle a non-existent instance.")

            return
        end

        if on_recycle then
            if on_recycle(instance) == false then
                return
            end
        end

        instance.Parent = nil
        pool.active[id] = nil

        table.insert(pool.inactive, instance)
    end

    function pool.get(id: any): T
        if pool.active[id] then
            return pool.active[id]
        end

        return new(id)
    end

    function pool.get_next(): T
        local id = #pool.active + 1

        return new(id)
    end

    function pool.recycle_id(id: any)
        recycle(id)
    end

    function pool.recycle_instance(instance: Instance)
        local id = table.find(pool.active, instance)

        recycle(id)
    end

    function pool.recycle_all()
        for id in pool.active do
            recycle(id)
        end
    end


    return pool
end



return object_pool
