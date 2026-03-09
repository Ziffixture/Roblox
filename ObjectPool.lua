--[[
Author     Ziffixture (74087102)
Date       02/23/2026 (MM/DD/YYYY)
Version    1.1.0
]]



type ObjectPool<T> = {
    active   : {T},
    inactive : {T},

    get      : (any) -> T,
    get_next : () -> T,

    recycle_id       : (any) -> (),
    recycle_instance : (T) -> (),
    recycle_all      : () -> (),
    trash_all        : () -> (),

    size : () -> number,

    iterate : () -> ((...any) -> any, {any}),
}



local function object_pool<T>(prefab: T & Instance, on_recycle: ((T) -> ())?): T
    local pool = {} :: ObjectPool<T>
    
    local size     = 0
    local active   = {}
    local inactive = {}


    local function get_active_id_by_instance(target: T): any?
        for id, instance in active do
            if instance == target then
                return id
            end
        end

        return nil
    end

    local function new(id: any?): T
        local instance: T

        if #inactive > 0 then
            instance = table.remove(inactive) :: T
        else
            instance = prefab:Clone()
        end

        if not id then
            id = instance
        end

        size       += 1
        active[id] = instance

        return instance
    end

    local function recycle(id: any)
        local instance = active[id]
        if not instance then
            return
        end

        if on_recycle then
            if on_recycle(instance) == false then
                return
            end
        end

        instance.Parent = nil

        size       -= 1
        active[id] = nil

        table.insert(inactive, instance)
    end

    local function trash(container: {T})
        for _, instance in container do
            instance:Destroy()
        end
    end

    function pool.get(id: any): T
        if active[id] then
            return active[id]
        end

        return new(id)
    end

    function pool.get_next(): T
        return new(nil)
    end

    function pool.recycle_id(id: any)
        recycle(id)
    end

    function pool.recycle_instance(instance: T)
        recycle(get_active_id_by_instance(instance))
    end

    function pool.recycle_all()
        for id in active do
            recycle(id)
        end
    end

    function pool.trash_all()
        trash(active)
        trash(inactive)

        size     = 0
        active   = {}
        inactive = {}
    end

    function pool.size(): number
        return size
    end

    function pool.iterate(): ((...any) -> any, {any})
        return next, active
    end


    return pool
end



return object_pool
