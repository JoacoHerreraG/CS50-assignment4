LevelMaker = Class{}

function LevelMaker.generate (width, height)
    local tiles = {}
    local entities = {}
    local objects = {}

    local tileID = TILE_ID_GROUND
    
    local topper = true
    local tileset = math.random(20)
    local topperset = math.random(20)

    local keySpawned = false
    local lockSpawned = false
    local keyVariant = math.random(4)


    -- insert blank tables into tiles for later access
    for x = 1, height do
        table.insert(tiles, {})
    end

    -- column by column generation instead of row
    for x = 1, width do
        local tileID = TILE_ID_EMPTY
        
        -- lay out the empty space
        for y = 1, 6 do
            table.insert(tiles[y],
                Tile(x, y, tileID, nil, tileset, topperset))
        end

        -- chance to just be emptiness
        if math.random(8) == 1 and x ~= 1 then
            for y = 7, height do
                table.insert(tiles[y],
                    Tile(x, y, tileID, nil, tileset, topperset))
            end
        else
            tileID = TILE_ID_GROUND

            local blockHeight = 4

            for y = 7, height do
                table.insert(tiles[y],
                    Tile(x, y, tileID, y == 7 and topper or nil, tileset, topperset))
            end

            -- chance to generate a pillar
            if math.random(8) == 1 and x ~= width then
                blockHeight = 2
                
                -- chance to generate bush on pillar
                if math.random(8) == 1 then
                    table.insert(objects,
                        GameObject {
                            texture = 'bushes',
                            x = (x - 1) * TILE_SIZE,
                            y = (4 - 1) * TILE_SIZE,
                            width = 16,
                            height = 16,
                            
                            -- select random frame from bush_ids whitelist, then random row for variance
                            frame = BUSH_IDS[math.random(#BUSH_IDS)] + (math.random(4) - 1) * 7
                        }
                    )
                end
                
                -- pillar tiles
                tiles[5][x] = Tile(x, 5, tileID, topper, tileset, topperset)
                tiles[6][x] = Tile(x, 6, tileID, nil, tileset, topperset)
                tiles[7][x].topper = nil
            
            -- chance to generate bushes
            elseif math.random(8) == 1 and x ~= width then
                table.insert(objects,
                    GameObject {
                        texture = 'bushes',
                        x = (x - 1) * TILE_SIZE,
                        y = (6 - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,
                        frame = BUSH_IDS[math.random(#BUSH_IDS)] + (math.random(4) - 1) * 7,
                        collidable = false
                    }
                )
            end

            -- chance to spawn a block
            if math.random(8) == 1 and x ~= width then
                table.insert(objects,

                    -- jump block
                    GameObject {
                        texture = 'jump-blocks',
                        x = (x - 1) * TILE_SIZE,
                        y = (blockHeight - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,

                        -- make it a random variant
                        frame = math.random(#JUMP_BLOCKS),
                        collidable = true,
                        hit = false,
                        solid = true,

                        onCollide = function(player, obj)

                            -- spawn a gem if we haven't already hit the block
                            if not obj.hit then

                                if math.random(5) == 1 then

                                    local gem = GameObject {
                                        texture = 'gems',
                                        x = (x - 1) * TILE_SIZE,
                                        y = (blockHeight - 1) * TILE_SIZE - 4,
                                        width = 16,
                                        height = 16,
                                        frame = math.random(#GEMS),
                                        collidable = true,
                                        consumable = true,
                                        solid = false,

                                        onConsume = function(player, object)
                                            gSounds['pickup']:play()
                                            player.score = player.score + 100
                                        end
                                    }
                                    
                                    -- make the gem move up from the block and play a sound
                                    Timer.tween(0.1, {
                                        [gem] = {y = (blockHeight - 2) * TILE_SIZE}
                                    })
                                    gSounds['powerup-reveal']:play()

                                    table.insert(objects, gem)

                                --chance to spawn a key, if gem didn't spawn
                                elseif math.random(2) == 1 and not keySpawned then
                                    
                                    keySpawned = true
                                    local key = GameObject {
                                        texture = 'keys-locks',
                                        x = (x - 1) * TILE_SIZE,
                                        y = (blockHeight - 1) * TILE_SIZE - 4,
                                        width = 16,
                                        height = 16,
                                        frame = keyVariant,
                                        collidable = true,
                                        consumable = true,
                                        solid = false,

                                        onConsume = function(player, object)
                                            gSounds['pickup']:play()
                                            player.grabbedKey = true
                                        end
                                    }
                                    
                                    -- make the key move up from the block and play a sound
                                    Timer.tween(0.1, {
                                        [key] = {y = (blockHeight - 2) * TILE_SIZE}
                                    })
                                    gSounds['powerup-reveal']:play()

                                    table.insert(objects, key)
                                end

                                obj.hit = true
                            end

                            gSounds['empty-block']:play()
                        end
                    }
                )

            --if block wasn't spawned then spawn a lock
            elseif math.random(10) == 1 and not lockSpawned then 

                lockSpawned = true
                table.insert(objects,
                    GameObject {
                        texture = 'keys-locks',
                        x = (x - 1) * TILE_SIZE,
                        y = (blockHeight - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,
                        --keyVariant + 4 so as to have same key and lock color
                        frame = keyVariant + 4,
                        collidable = true,
                        hit = false,
                        solid = true,
                        onCollide = function(player, obj)
                            if player.grabbedKey then
                                gSounds['pickup']:play()
                                obj.collidable = false
                                obj.solid = false
                                obj.visible = false
                                LevelMaker.spawnPole(width, height, objects)
                            else
                                gSounds['empty-block']:play()
                            end
                        end
                    }
                )
            end
        end
    end

    local map = TileMap(width, height)
    map.tiles = tiles
    
    return GameLevel(entities, objects, map)
end

function LevelMaker.spawnPole(mapWidth, mapHeight, objects)
    local poleVariant = math.random(6)
    local middlePole = poleVariant + 9
    local bottomPole = poleVariant + 18
    local flagVariant = math.random(4)
    local flagColor = 7 + 9 * (flagVariant - 1)

    table.insert(objects,
        GameObject {
            texture = 'flags',
            x = (mapWidth - 1) * TILE_SIZE,
            y = (5) * TILE_SIZE,
            width = 16,
            height = 16,
            frame = bottomPole,
            collidable = true,
            consumable = true,
            solid = false,
            onConsume = function(player, obj)
                LevelMaker.newLevel(player)
            end
        }
    )
    table.insert(objects,
        GameObject {
            texture = 'flags',
            x = (mapWidth - 1) * TILE_SIZE,
            y = (4) * TILE_SIZE,
            width = 16,
            height = 16,
            frame = middlePole,
            collidable = false,
            consumable = true,
            solid = false,
            onConsume = function(player, obj)
                LevelMaker.newLevel(player)
            end
        }
    )
    table.insert(objects,
        GameObject {
            texture = 'flags',
            x = (mapWidth - 1) * TILE_SIZE,
            y = (3) * TILE_SIZE,
            width = 16,
            height = 16,
            frame = poleVariant,
            collidable = false,
            consumable = true,
            solid = false,
            onConsume = function(player, obj)
                LevelMaker.newLevel(player)
            end
        }
    )
    table.insert(objects,
        GameObject {
            texture = 'flags',
            x = (mapWidth - 1) * TILE_SIZE + 8,
            y = (3) * TILE_SIZE + 8,
            width = 16,
            height = 16,
            frame = flagColor,
            collidable = false,
            solid = false
        }
    )
end

function LevelMaker.newLevel (player)
    gStateMachine:change('play', {
        level = LevelMaker.generate(50 + player.score / 50, 10),
        score = player.score
    })
end