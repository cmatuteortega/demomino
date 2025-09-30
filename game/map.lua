Map = {}

-- Generate a new DAG-based map with 8-12 depth levels and 5-6 possible paths
function Map.generateMap(screenWidth, screenHeight)
    -- Use default dimensions if not provided for backward compatibility
    screenWidth = screenWidth or 800
    screenHeight = screenHeight or 600
    local map = {
        nodes = {},        -- All nodes in the DAG
        levels = {},       -- Nodes organized by depth level  
        currentNode = nil,
        completedNodes = {},
        availableNodes = {},
        traversedConnections = {}, -- Track specific from→to connections actually taken
        cameraX = 0,       -- Camera offset for scrolling
        totalWidth = 0,    -- Total map width
        
        -- Camera animation system
        cameraTargetX = 0, -- Target camera position for animation
        cameraAnimating = false, -- Flag to track if camera is animating
        cameraAnimation = nil, -- Reference to active camera animation
        userDragging = false, -- Flag to prevent auto camera updates during manual dragging
        manualCameraMode = false, -- Flag to keep manual camera position after dragging ends
        
        -- Path preview animation system
        previewTiles = {}, -- Preview tiles for node selection animation
        
        -- Legacy compatibility for renderer
        columns = {}
    }
    
    -- Configuration for DAG structure
    local numLevels = love.math.random(8, 12)  -- 8-12 depth levels
    local maxPaths = 4                         -- 4 maximum rows for sparse placement
    local minConnections = 2  -- Minimum connections per node (except final level nodes)
    local maxConnections = 4  -- Maximum connections per node
    
    -- Initialize levels structure
    for depth = 1, numLevels do
        map.levels[depth] = {}
        map.columns[depth] = {} -- Legacy compatibility
    end
    
    -- Generate start node using sparse row selection
    local startRows = Map.selectSparseRows(1, numLevels, maxPaths)
    local startNode = Map.createNode(1, startRows[1], "start")
    map.nodes[startNode.id] = startNode
    table.insert(map.levels[1], startNode)
    table.insert(map.columns[1], startNode) -- Legacy
    map.currentNode = startNode
    map.completedNodes[startNode.id] = true
    
    -- Generate boss node using sparse row selection  
    local bossRows = Map.selectSparseRows(numLevels, numLevels, maxPaths)
    local bossNode = Map.createNode(numLevels, bossRows[1], "boss")
    map.nodes[bossNode.id] = bossNode
    table.insert(map.levels[numLevels], bossNode)
    table.insert(map.columns[numLevels], bossNode) -- Legacy
    
    -- Generate intermediate levels (2 to numLevels-1) with sparse row placement
    for depth = 2, numLevels - 1 do
        -- Select which rows to populate at this level (sparse placement)
        local selectedRows = Map.selectSparseRows(depth, numLevels, maxPaths)
        
        -- Generate nodes for selected rows only
        for _, rowNumber in ipairs(selectedRows) do
            local nodeType = Map.selectRandomNodeType(depth, numLevels)
            local node = Map.createNode(depth, rowNumber, nodeType)
            map.nodes[node.id] = node
            table.insert(map.levels[depth], node)
            table.insert(map.columns[depth], node) -- Legacy
        end
    end
    
    -- Generate DAG connections
    Map.generateDAGConnections(map, minConnections, maxConnections)
    
    -- Validate DAG structure and ensure all paths lead to boss
    Map.validateAndFixDAG(map)
    
    -- Set initial available nodes
    Map.updateAvailableNodes(map)
    
    -- Position nodes first before creating tiles
    Map.calculateNodePositions(map, screenWidth, screenHeight)
    
    -- Generate domino tiles for visualization
    Map.generateMapTiles(map)
    
    -- Do NOT reveal initial paths - paths are only revealed after first node selection
    -- Map.updatePathVisibility(map) -- Removed: no initial path visibility
    
    return map
end

-- Create a single node with proper DAG structure
function Map.createNode(depth, path, nodeType)
    -- Generate proper unique ID using depth and path
    local nodeId = "node_" .. depth .. "_" .. path
    
    return {
        id = nodeId,           -- Unique identifier for DAG
        depth = depth,         -- Level in the DAG (1-12)
        path = path,           -- Path index (1-6)
        nodeType = nodeType,   -- "start", "combat", "tiles", "artifacts", "contracts", "boss"
        completed = false,
        connections = {},      -- Array of connected node IDs (directed edges)
        position = {x = 0, y = 0}, -- Position coordinates
        
        -- Legacy fields for compatibility with existing renderer
        column = depth,
        lane = path,
        x = 0,
        y = 0
    }
end

-- Select a random node type for regular nodes with balanced distribution
-- Now more combat-aware to reduce post-generation corrections
function Map.selectRandomNodeType(depth, numLevels)
    local nodeTypes = {"combat", "tiles", "artifacts", "contracts"}
    
    -- Increase combat probability to ensure adequate coverage
    -- We need at least 3 combat nodes per path, so be more aggressive
    local combatChance
    
    if depth <= 3 then
        -- Early levels: high combat chance to establish baseline
        combatChance = 0.6
    elseif depth <= numLevels * 0.6 then
        -- Middle levels: moderate combat chance
        combatChance = 0.5
    else
        -- Later levels: still reasonable combat chance
        combatChance = 0.4
    end
    
    if love.math.random() < combatChance then
        return "combat"
    else
        -- Randomly select from the other 3 types
        local otherTypes = {"tiles", "artifacts", "contracts"}
        return otherTypes[love.math.random(1, #otherTypes)]
    end
end

-- Select which rows (1-4) to populate at a level for sparse placement
function Map.selectSparseRows(depth, numLevels, maxRows)
    if depth == 1 then
        -- Start node: single middle row for good branching
        return {2}
    elseif depth == numLevels then
        -- Boss node: prefer middle rows for better connectivity from all previous nodes
        -- Choose from middle 2 rows (2 or 3) to maximize connection opportunities
        return {love.math.random(2, 3)}
    else
        -- Intermediate levels: connectivity-focused placement
        local levelProgress = (depth - 2) / (numLevels - 3) -- 0 to 1
        
        -- Ensure minimum 2 nodes per level for connectivity, with gradual expansion
        local numRows
        if depth <= 3 or depth >= numLevels - 2 then
            -- Early and late levels: fewer nodes but strategic placement
            numRows = 2
        else
            -- Middle levels: more nodes for variety, but always at least 2
            local pathExpansion = math.sin(levelProgress * math.pi) -- Bell curve for variety
            numRows = math.max(2, math.min(maxRows, math.floor(2 + pathExpansion * 2)))
        end
        
        local selectedRows = {}
        
        -- Always ensure connectivity-friendly placement
        if numRows == 2 then
            -- Two nodes: choose positions that support good connectivity
            if depth <= 3 then
                -- Early levels: spread from center for branching
                selectedRows = {2, 3}
            elseif depth >= numLevels - 2 then
                -- Late levels: converge toward center for boss connectivity
                selectedRows = {2, 3}
            else
                -- Middle levels: varied but connected placement
                local patterns = {{1, 3}, {2, 4}, {1, 4}, {2, 3}}
                selectedRows = patterns[love.math.random(1, #patterns)]
            end
        elseif numRows == 3 then
            -- Three nodes: multiple connectivity options
            local patterns = {{1, 2, 3}, {2, 3, 4}, {1, 3, 4}, {1, 2, 4}}
            selectedRows = patterns[love.math.random(1, #patterns)]
        else
            -- Four nodes: all rows for maximum connectivity
            selectedRows = {1, 2, 3, 4}
        end
        
        return selectedRows
    end
end

-- Generate DAG connections with strategic commitment points and crossing prevention
function Map.generateDAGConnections(map, minConnections, maxConnections)
    local numLevels = #map.levels
    
    -- Track existing paths for each level transition to prevent crossings
    local existingPaths = {}
    for depth = 1, numLevels - 1 do
        existingPaths[depth] = {}
    end
    
    -- Connect each level to the next levels (not just immediate next)
    for depth = 1, numLevels - 1 do
        local currentLevel = map.levels[depth]
        
        for _, node in ipairs(currentLevel) do
            -- Create commitment points: some nodes have only 1 connection for strategic decisions
            local isCommitmentPoint = Map.shouldBeCommitmentPoint(depth, numLevels, node)
            local numConnections
            
            if isCommitmentPoint then
                numConnections = 1 -- Force commitment
            else
                numConnections = love.math.random(minConnections, maxConnections)
            end
            
            local connectionsAdded = 0
            
            -- New connection rules: direct next-level connections + same-row exceptions
            local possibleTargets = {}
            
            -- Primary rule: collect nodes from the immediate next level with adjacency constraint (±1 row)
            local nextLevel = depth + 1
            if map.levels[nextLevel] then
                for _, targetNode in ipairs(map.levels[nextLevel]) do
                    -- Use the new validation function to check if this connection is valid
                    if Map.isValidConnection(node, targetNode, map) then
                        table.insert(possibleTargets, {node = targetNode, distance = 1, type = "adjacent"})
                    end
                end
            end
            
            -- Exception: allow connections to skip exactly 1 level (same-row nodes only)
            local skipDepth = nextLevel + 1 -- Only allow skipping exactly 1 level
            if skipDepth <= numLevels and map.levels[skipDepth] then
                for _, targetNode in ipairs(map.levels[skipDepth]) do
                    -- Use the new validation function to check if this connection is valid
                    if Map.isValidConnection(node, targetNode, map) then
                        table.insert(possibleTargets, {node = targetNode, distance = skipDepth - depth, type = "same_row"})
                    end
                end
            end
            
            -- Calculate current path lengths for balance scoring
            local currentPathLengths = Map.calculatePathLengths(map)
            
            -- Sort targets: prioritize adjacent connections, then consider path balance
            table.sort(possibleTargets, function(a, b)
                -- First priority: prefer adjacent connections over same-row skip connections
                if a.type ~= b.type then
                    return a.type == "adjacent" -- adjacent comes before same_row
                end
                
                -- Second priority: for same type, prefer closer connections
                if a.distance ~= b.distance then
                    return a.distance < b.distance
                end
                
                -- Third priority: use path balance scoring for tie-breaking
                local scoreA = Map.getPathBalanceScore(map, node, a.node, currentPathLengths)
                local scoreB = Map.getPathBalanceScore(map, node, b.node, currentPathLengths)
                if scoreA ~= scoreB then
                    return scoreA > scoreB -- Higher score is better
                end
                
                -- Final tie-breaker: stable sort by node ID
                return a.node.id < b.node.id
            end)
            
            -- Add connections up to the desired number with crossing prevention
            for _, target in ipairs(possibleTargets) do
                if connectionsAdded >= numConnections then
                    break
                end
                
                -- Avoid duplicate connections
                local alreadyConnected = false
                for _, existingId in ipairs(node.connections) do
                    if existingId == target.node.id then
                        alreadyConnected = true
                        break
                    end
                end
                
                -- Check if this path would cross existing paths for the same level transition
                local wouldCross = false
                local targetDepth = target.node.depth
                if existingPaths[depth] then
                    wouldCross = Map.wouldPathsCross(node.path, target.node.path, existingPaths[depth])
                end
                
                if not alreadyConnected and not wouldCross then
                    table.insert(node.connections, target.node.id)
                    connectionsAdded = connectionsAdded + 1
                    
                    -- Track this path to prevent future crossings
                    table.insert(existingPaths[depth], {
                        fromLane = node.path,
                        toLane = target.node.path,
                        targetDepth = targetDepth
                    })
                end
            end
            
            -- Ensure minimum connections are met (unless it's a commitment point)
            -- Apply progressively more permissive connection attempts for connectivity
            if not isCommitmentPoint then
                -- First attempt: strict rules (no crossing)
                while connectionsAdded < minConnections and #possibleTargets > connectionsAdded do
                    local fallbackTarget = nil
                    for i = connectionsAdded + 1, #possibleTargets do
                        local candidate = possibleTargets[i]
                        
                        -- Check if already connected
                        local alreadyConnected = false
                        for _, existingId in ipairs(node.connections) do
                            if existingId == candidate.node.id then
                                alreadyConnected = true
                                break
                            end
                        end
                        
                        -- Check crossing constraint
                        local wouldCross = false
                        if existingPaths[depth] then
                            wouldCross = Map.wouldPathsCross(node.path, candidate.node.path, existingPaths[depth])
                        end
                        
                        -- Validate connection constraints
                        local validConnection = Map.isValidConnection(node, candidate.node, map)
                        
                        if not alreadyConnected and not wouldCross and validConnection then
                            fallbackTarget = candidate
                            break
                        end
                    end
                    
                    if fallbackTarget then
                        table.insert(node.connections, fallbackTarget.node.id)
                        connectionsAdded = connectionsAdded + 1
                        
                        -- Track this fallback path
                        table.insert(existingPaths[depth], {
                            fromLane = node.path,
                            toLane = fallbackTarget.node.path,
                            targetDepth = fallbackTarget.node.depth
                        })
                    else
                        break -- No more valid targets with strict rules
                    end
                end
                
                -- Second attempt: relax crossing prevention for connectivity
                if connectionsAdded < minConnections then
                    for i = connectionsAdded + 1, #possibleTargets do
                        local candidate = possibleTargets[i]
                        
                        -- Check if already connected
                        local alreadyConnected = false
                        for _, existingId in ipairs(node.connections) do
                            if existingId == candidate.node.id then
                                alreadyConnected = true
                                break
                            end
                        end
                        
                        -- Only check connection validity, allow crossing for connectivity
                        local validConnection = Map.isValidConnection(node, candidate.node, map)
                        
                        if not alreadyConnected and validConnection then
                            table.insert(node.connections, candidate.node.id)
                            connectionsAdded = connectionsAdded + 1
                            
                            -- Track this emergency path (may cross others)
                            table.insert(existingPaths[depth], {
                                fromLane = node.path,
                                toLane = candidate.node.path,
                                targetDepth = candidate.node.depth
                            })
                            
                            if connectionsAdded >= minConnections then
                                break
                            end
                        end
                    end
                end
                
                -- Third attempt: emergency connectivity - relax all distance rules
                if connectionsAdded == 0 then
                    -- Find ANY forward connection to prevent isolation
                    for targetDepth = depth + 1, numLevels do
                        if map.levels[targetDepth] then
                            for _, targetNode in ipairs(map.levels[targetDepth]) do
                                -- Check if already connected
                                local alreadyConnected = false
                                for _, existingId in ipairs(node.connections) do
                                    if existingId == targetNode.id then
                                        alreadyConnected = true
                                        break
                                    end
                                end
                                
                                if not alreadyConnected then
                                    table.insert(node.connections, targetNode.id)
                                    connectionsAdded = connectionsAdded + 1
                                    print("Emergency connection added: " .. node.id .. " -> " .. targetNode.id)
                                    break
                                end
                            end
                            if connectionsAdded > 0 then break end
                        end
                    end
                end
            end
        end
    end
end

-- Determine if a node should be a commitment point (single connection)
function Map.shouldBeCommitmentPoint(depth, totalLevels, node)
    -- Don't make start node or nodes very close to boss commitment points
    if depth == 1 or depth >= totalLevels - 1 then
        return false
    end
    
    -- Create commitment points at strategic intervals
    -- Make approximately 30-40% of nodes commitment points for strategic depth
    local baseCommitmentChance = 0.25
    
    -- Increase chance for commitment points in middle sections where choices matter most
    local middleSection = depth > totalLevels * 0.3 and depth < totalLevels * 0.7
    local commitmentChance = middleSection and 0.35 or baseCommitmentChance
    
    -- Add some variation based on depth - more commitment points at key strategic levels
    if depth == math.floor(totalLevels * 0.4) or depth == math.floor(totalLevels * 0.6) then
        commitmentChance = 0.6 -- Higher chance at key decision levels
    end
    
    -- Use deterministic method based on node properties to ensure consistency
    local hash = 0
    for i = 1, #node.id do
        hash = hash + string.byte(node.id, i) * (i + depth) -- More variation
    end
    hash = hash + node.depth * 17 + node.path * 31 -- Add more entropy
    
    return (hash % 100) < (commitmentChance * 100)
end

-- Remove nodes that cannot be reached from the starting point
function Map.removeUnreachableNodes(map)
    local startNode = map.currentNode
    if not startNode then return end
    
    -- Forward reachability analysis from start node
    local reachableNodes = {[startNode.id] = true}
    
    -- For each level working forward, mark nodes that can be reached from start
    for depth = 1, #map.levels - 1 do
        local currentLevel = map.levels[depth]
        
        for _, node in ipairs(currentLevel) do
            if reachableNodes[node.id] then
                -- This node is reachable, mark all its connections as reachable
                for _, connectionId in ipairs(node.connections) do
                    reachableNodes[connectionId] = true
                end
            end
        end
    end
    
    -- Remove unreachable nodes from all levels and data structures
    for depth = 1, #map.levels do
        local level = map.levels[depth]
        local newLevel = {}
        local newColumn = {}
        
        for _, node in ipairs(level) do
            if reachableNodes[node.id] then
                -- Keep reachable nodes
                table.insert(newLevel, node)
                table.insert(newColumn, node)
            else
                -- Remove unreachable nodes
                map.nodes[node.id] = nil
                print("Removed unreachable node: " .. node.id .. " at depth " .. depth .. " row " .. node.path)
            end
        end
        
        map.levels[depth] = newLevel
        map.columns[depth] = newColumn
    end
    
    -- Clean up connections that point to removed nodes
    for nodeId, node in pairs(map.nodes) do
        local validConnections = {}
        for _, connectionId in ipairs(node.connections) do
            if map.nodes[connectionId] then
                table.insert(validConnections, connectionId)
            end
        end
        node.connections = validConnections
    end
end

-- Validate and fix DAG structure to ensure proper connectivity
function Map.validateAndFixDAG(map)
    local numLevels = #map.levels
    
    -- Remove unreachable nodes first (forward reachability from start)
    Map.removeUnreachableNodes(map)
    
    -- Check if boss node still exists after unreachable node removal
    if #map.levels[numLevels] == 0 then
        -- Boss was removed, regenerate map (this should be rare)
        print("Warning: Boss node was unreachable, regenerating map...")
        return Map.generateMap() -- Recursive regeneration
    end
    
    local bossNode = map.levels[numLevels][1] -- Boss is always the single node at final level
    
    -- Ensure all remaining nodes can reach the boss node (backward connectivity)
    Map.ensureAllPathsReachBoss(map, bossNode)
    
    -- Verify DAG structure (no cycles)
    Map.validateAcyclicStructure(map)
    
    -- Ensure boss node has incoming connections
    Map.ensureBossHasConnections(map, bossNode)
    
    -- NEW: Validate and improve path balance
    Map.validatePathBalance(map)
    
    -- NEW: Validate combat node requirements (minimum 3 combat nodes per path)
    local combatValid = Map.validateCombatRequirements(map)
    if not combatValid then
        print("Combat requirements not met, attempting correction...")
        local combatCorrected = Map.correctCombatDeficiency(map)
        if not combatCorrected then
            print("Critical: Could not satisfy combat requirements, regenerating map...")
            return Map.generateMap() -- Recursive regeneration as fallback
        end
    end
    
    -- FINAL: Comprehensive connectivity validation with regeneration fallback
    local connectivityValid = Map.performFinalConnectivityCheck(map)
    if not connectivityValid then
        print("Critical: Final connectivity check failed, regenerating map...")
        return Map.generateMap() -- Recursive regeneration as last resort
    end
end

-- Ensure all nodes have a path to the boss node
function Map.ensureAllPathsReachBoss(map, bossNode)
    local numLevels = #map.levels
    local maxAttempts = 3
    
    for attempt = 1, maxAttempts do
        -- Work backwards from boss to ensure connectivity
        local connectedNodes = {[bossNode.id] = true}
        local fixedNodes = {}
        
        -- For each level working backwards, mark nodes that can reach boss
        for depth = numLevels - 1, 1, -1 do
            local currentLevel = map.levels[depth]
            
            for _, node in ipairs(currentLevel) do
                local canReachBoss = false
                
                -- Check if any of this node's connections can reach the boss
                for _, connectionId in ipairs(node.connections) do
                    if connectedNodes[connectionId] then
                        canReachBoss = true
                        break
                    end
                end
                
                if canReachBoss then
                    connectedNodes[node.id] = true
                else
                    -- This node can't reach boss, add a connection to a reachable node
                    local fixed = Map.addConnectionToBoss(map, node, connectedNodes, depth, attempt)
                    if fixed then
                        connectedNodes[node.id] = true
                        table.insert(fixedNodes, node.id)
                    else
                        print("Warning: Could not fix connectivity for node " .. node.id .. " on attempt " .. attempt)
                    end
                end
            end
        end
        
        -- Verify all nodes can reach boss
        local allConnected = true
        for nodeId, node in pairs(map.nodes) do
            if not connectedNodes[nodeId] then
                allConnected = false
                print("Node " .. nodeId .. " cannot reach boss after attempt " .. attempt)
            end
        end
        
        if allConnected then
            if #fixedNodes > 0 then
                print("Successfully fixed connectivity for " .. #fixedNodes .. " nodes on attempt " .. attempt)
            end
            break
        elseif attempt == maxAttempts then
            print("Warning: Could not ensure all paths reach boss after " .. maxAttempts .. " attempts")
        end
    end
end

-- Validate if a connection between two nodes respects the new constraints
function Map.isValidConnection(fromNode, toNode, map)
    -- Level constraint: can only connect to immediate next level or skip exactly 1 level
    local levelDifference = toNode.depth - fromNode.depth
    if levelDifference < 1 or levelDifference > 2 then
        return false -- Must connect forward by 1 or 2 levels only
    end
    
    -- Row constraint depends on level difference
    if levelDifference == 1 then
        -- Adjacent level: allow ±1 row difference
        local rowDifference = math.abs(toNode.path - fromNode.path)
        if rowDifference > 1 then
            return false -- Adjacent levels can only connect to ±1 row
        end
    elseif levelDifference == 2 then
        -- Skip level: require same row only
        if toNode.path ~= fromNode.path then
            return false -- Skip connections must be same row
        end
        
        -- Intermediate node constraint: no nodes in same row between source and target
        local intermediateDepth = fromNode.depth + 1
        if map.levels[intermediateDepth] then
            for _, intermediateNode in ipairs(map.levels[intermediateDepth]) do
                if intermediateNode.path == fromNode.path then
                    return false -- Skip connection blocked by intermediate node in same row
                end
            end
        end
    end
    
    return true -- Connection is valid
end

-- Add a connection from a node to ensure it can reach the boss
function Map.addConnectionToBoss(map, node, connectedNodes, currentDepth, attempt)
    local numLevels = #map.levels
    attempt = attempt or 1
    
    -- Check if this node should be a commitment point
    local isCommitmentPoint = Map.shouldBeCommitmentPoint(currentDepth, numLevels, node)
    
    -- First attempt: follow connection constraints
    if attempt == 1 then
        -- Find the closest level with connected nodes, respecting connection constraints
        for nextDepth = currentDepth + 1, math.min(numLevels, currentDepth + 2) do
            local targetLevel = map.levels[nextDepth]
            
            for _, targetNode in ipairs(targetLevel) do
                if connectedNodes[targetNode.id] and Map.isValidConnection(node, targetNode, map) then
                    -- Add connection to this reachable node
                    table.insert(node.connections, targetNode.id)
                    print("Fixed connectivity: " .. node.id .. " -> " .. targetNode.id .. " (standard rules)")
                    return true
                end
            end
        end
    end
    
    -- Second attempt: relax distance constraints but maintain forward direction
    if attempt >= 2 then
        for nextDepth = currentDepth + 1, numLevels do
            local targetLevel = map.levels[nextDepth]
            
            for _, targetNode in ipairs(targetLevel) do
                if connectedNodes[targetNode.id] then
                    -- Check if not already connected
                    local alreadyConnected = false
                    for _, existingId in ipairs(node.connections) do
                        if existingId == targetNode.id then
                            alreadyConnected = true
                            break
                        end
                    end
                    
                    if not alreadyConnected then
                        table.insert(node.connections, targetNode.id)
                        print("Fixed connectivity: " .. node.id .. " -> " .. targetNode.id .. " (relaxed rules)")
                        return true
                    end
                end
            end
        end
    end
    
    -- Third attempt: emergency connection to boss directly
    if attempt >= 3 then
        local bossNode = nil
        for _, node in pairs(map.nodes) do
            if node.nodeType == "boss" then
                bossNode = node
                break
            end
        end
        
        if bossNode then
            -- Check if not already connected to boss
            local alreadyConnected = false
            for _, existingId in ipairs(node.connections) do
                if existingId == bossNode.id then
                    alreadyConnected = true
                    break
                end
            end
            
            if not alreadyConnected then
                table.insert(node.connections, bossNode.id)
                print("Emergency connection: " .. node.id .. " -> " .. bossNode.id .. " (direct to boss)")
                return true
            end
        end
    end
    
    return false -- Could not fix connectivity
end

-- Validate that the DAG has no cycles (should be impossible with our level-based generation)
function Map.validateAcyclicStructure(map)
    -- Simple validation: ensure connections only go to higher depth levels
    for nodeId, node in pairs(map.nodes) do
        for _, connectionId in ipairs(node.connections) do
            local targetNode = map.nodes[connectionId]
            if targetNode and targetNode.depth <= node.depth then
                -- This should not happen with our generation algorithm
                error("DAG validation failed: cycle detected from " .. nodeId .. " to " .. connectionId)
            end
        end
    end
end

-- Ensure the boss node has at least one incoming connection
function Map.ensureBossHasConnections(map, bossNode)
    local hasIncomingConnection = false
    
    -- Check if any node connects to the boss
    for nodeId, node in pairs(map.nodes) do
        if nodeId ~= bossNode.id then
            for _, connectionId in ipairs(node.connections) do
                if connectionId == bossNode.id then
                    hasIncomingConnection = true
                    break
                end
            end
            if hasIncomingConnection then break end
        end
    end
    
    -- If boss has no incoming connections, connect it to the previous level(s) respecting constraints
    if not hasIncomingConnection then
        local numLevels = #map.levels
        
        -- Check both previous level and 2-levels back (within constraint limits)
        for checkDepth = math.max(1, numLevels - 2), numLevels - 1 do
            local candidateLevel = map.levels[checkDepth]
            
            if candidateLevel and #candidateLevel > 0 then
                -- Find nodes that can validly connect to boss
                local validCandidates = {}
                for _, candidateNode in ipairs(candidateLevel) do
                    if Map.isValidConnection(candidateNode, bossNode, map) then
                        table.insert(validCandidates, candidateNode)
                    end
                end
                
                -- Connect at least one valid candidate to boss
                if #validCandidates > 0 then
                    local selectedNode = validCandidates[love.math.random(1, #validCandidates)]
                    table.insert(selectedNode.connections, bossNode.id)
                    hasIncomingConnection = true
                    break
                end
            end
        end
        
        -- If still no connection possible with constraints, this indicates a structural issue
        if not hasIncomingConnection then
            print("Warning: Could not connect boss node while respecting constraints - may need map regeneration")
        end
    end
end

-- Update which nodes are available for selection
function Map.updateAvailableNodes(map)
    map.availableNodes = {}
    
    if not map.currentNode then
        return
    end
    
    -- Available nodes are those connected to the current node
    for _, connectionId in ipairs(map.currentNode.connections) do
        table.insert(map.availableNodes, connectionId)
    end
end

-- Move to a specific node
function Map.moveToNode(map, nodeId)
    -- Verify the node is available
    local isAvailable = false
    for _, availableId in ipairs(map.availableNodes) do
        if availableId == nodeId then
            isAvailable = true
            break
        end
    end
    
    if not isAvailable then
        return false -- Invalid move
    end
    
    -- Find the target node
    local targetNode = Map.findNodeById(map, nodeId)
    if not targetNode then
        return false
    end
    
    -- Mark current node as completed and move to new node
    local fromNode = map.currentNode
    if fromNode then
        fromNode.completed = true
        map.completedNodes[fromNode.id] = true
        
        -- Record the specific connection traversed
        if not map.traversedConnections[fromNode.id] then
            map.traversedConnections[fromNode.id] = {}
        end
        map.traversedConnections[fromNode.id][targetNode.id] = true
    end
    
    map.currentNode = targetNode
    map.completedNodes[targetNode.id] = true
    
    -- Update path visibility to reveal paths from newly completed nodes
    Map.updatePathVisibility(map)
    
    -- Update available nodes for next move
    Map.updateAvailableNodes(map)
    
    -- Trigger smooth camera animation to focus on the newly selected node
    -- Only animate if we have screen width available and the node depth changed
    if gameState and gameState.screen and gameState.screen.width and gameState.screen.width > 0 then
        local shouldAnimate = true
        
        -- Don't animate if we're already at the same depth level (prevents unnecessary animations)
        if fromNode and fromNode.depth == targetNode.depth then
            shouldAnimate = false
        end
        
        -- Additional safety: ensure target node has valid depth
        if not targetNode.depth or targetNode.depth < 1 then
            shouldAnimate = false
        end
        
        if shouldAnimate then
            -- Wrap in pcall for extra safety in case animation system has issues
            local success, result = pcall(function()
                return Map.animateCameraTo(map, targetNode.depth, gameState.screen.width)
            end)
            
            if not success then
                print("Warning: Camera animation failed:", result)
                -- Fallback to immediate camera update
                Map.updateCamera(map, gameState.screen.width)
            end
        end
    end
    
    return true
end

-- Find a node by ID using the DAG structure
function Map.findNodeById(map, nodeId)
    return map.nodes[nodeId]
end

-- Check if the map is completed (reached boss node)
function Map.isCompleted(map)
    return map.currentNode and (map.currentNode.nodeType == "boss" or map.currentNode.nodeType == "final")
end

-- Get node at screen coordinates (for touch detection)
function Map.getNodeAt(map, x, y)
    -- Check node tiles first (they have priority for interaction)
    if map.tiles then
        for _, tile in ipairs(map.tiles) do
            if tile.mapNode and Map.isTileHit(tile, x, y) then
                return tile.mapNode
            end
        end
    end
    
    return nil
end

-- Check if a touch point hits a domino tile
function Map.isTileHit(tile, x, y)
    local tileWidth, tileHeight = UI.Layout.getTileSize()
    
    -- Adjust size based on orientation
    if tile.orientation == "horizontal" then
        tileWidth, tileHeight = tileHeight, tileWidth
    end
    
    -- Scale down for tiny map tiles
    tileWidth = tileWidth * 0.4
    tileHeight = tileHeight * 0.4
    
    -- Check rectangular collision
    local halfWidth = tileWidth / 2
    local halfHeight = tileHeight / 2
    
    return x >= tile.x - halfWidth and x <= tile.x + halfWidth and
           y >= tile.y - halfHeight and y <= tile.y + halfHeight
end

-- Check if a node is available for selection
function Map.isNodeAvailable(map, nodeId)
    for _, availableId in ipairs(map.availableNodes) do
        if availableId == nodeId then
            return true
        end
    end
    return false
end

-- Get visual properties
function Map.getNodeRadius()
    return UI.Layout.scale(30)
end

function Map.getConnectionWidth()
    return UI.Layout.scale(3)
end

-- Calculate positions for all nodes (DAG layout with proper spacing based on sprite dimensions)
function Map.calculateNodePositions(map, screenWidth, screenHeight)
    local marginX = UI.Layout.scale(60)
    local marginY = UI.Layout.scale(120) -- Leave space for title
    
    -- Calculate proper level spacing based on domino chain path structure
    -- Create temp tiles to get accurate sprite dimensions
    local tempNodeTile = Domino.new(1, 1) -- Node tile (vertical double)
    tempNodeTile.orientation = "vertical"
    tempNodeTile.isMapTile = true
    
    local tempHorizontalTile = Domino.new(1, 2) -- Horizontal path tile
    tempHorizontalTile.orientation = "horizontal"
    tempHorizontalTile.isMapTile = true
    
    local tempVerticalTile = Domino.new(1, 2) -- Vertical path tile  
    tempVerticalTile.orientation = "vertical"
    tempVerticalTile.isMapTile = true
    
    -- Get actual sprite dimensions
    local nodeWidth = Map.getMapTileDisplayWidth(tempNodeTile)
    local horizontalWidth = Map.getMapTileDisplayWidth(tempHorizontalTile)
    local verticalWidth = Map.getMapTileDisplayWidth(tempVerticalTile)
    local verticalHeight = Map.getMapTileDisplayHeight(tempVerticalTile)
    
    -- Calculate level spacing: exactly 2 horizontal tiles between nodes
    -- [Node] → [H-Tile] → [H-Tile] → [Node]
    local levelSpacing = nodeWidth + 2 * horizontalWidth
    
    -- Adjust vertical spacing for diagonal paths - accommodate 2 vertical tiles
    -- Need space for 2 vertical tiles plus gaps for diagonal path sequences
    local tileGap = UI.Layout.scale(2)
    local pathSpacing = math.max(UI.Layout.scale(90), 2 * verticalHeight + 3 * tileGap)
    -- Reduce row spacing by half the height of a vertical tile
    pathSpacing = pathSpacing - verticalHeight * 0.2
    
    local numLevels = #map.levels
    local maxPathsInLevel = 0
    
    -- Find maximum number of paths in any level for height calculation
    for _, level in ipairs(map.levels) do
        maxPathsInLevel = math.max(maxPathsInLevel, #level)
    end
    
    -- Calculate total map dimensions with new spacing
    map.totalWidth = marginX + (numLevels - 1) * levelSpacing + marginX
    -- Use 4-row maximum for consistent height calculation with sparse placement
    local totalHeight = marginY + (4 - 1) * pathSpacing + marginY
    
    -- Calculate starting positions
    local startY = marginY + UI.Layout.scale(50)
    
    -- Position nodes level by level
    for depth, level in ipairs(map.levels) do
        local baseX = marginX + (depth - 1) * levelSpacing
        local worldX = baseX - map.cameraX -- Apply camera offset
        
        local numNodesInLevel = #level
        
        -- Calculate Y positions for sparse row placement
        local availableHeight = screenHeight - 2 * marginY - UI.Layout.scale(100)
        -- With 4 max rows, total height spans 3 * pathSpacing
        local totalPossibleHeight = 3 * pathSpacing
        local levelStartY = startY + (availableHeight - totalPossibleHeight) / 2
        
        -- Position each node in this level using actual row numbers for sparse placement
        for pathIndex, node in ipairs(level) do
            -- Store both world position and screen position
            node.position.x = baseX
            node.position.y = levelStartY + (node.path - 1) * pathSpacing -- Use actual row number for sparse positioning
            
            -- Screen position with camera offset
            node.x = worldX
            node.y = node.position.y
            
            -- Legacy compatibility
            node.column = depth
            node.lane = node.path -- Use actual row number, not pathIndex
        end
    end
end

-- Update camera position to follow current node
function Map.updateCamera(map, screenWidth)
    if not map.currentNode then return end
    
    -- If camera is animating, let the animation system handle positioning
    if map.cameraAnimating then
        return
    end
    
    -- Use the same spacing calculation as node positioning (domino chain structure)
    local tempNodeTile = Domino.new(1, 1)
    tempNodeTile.orientation = "vertical"
    tempNodeTile.isMapTile = true
    
    local tempHorizontalTile = Domino.new(1, 2)
    tempHorizontalTile.orientation = "horizontal"
    tempHorizontalTile.isMapTile = true
    
    local tempVerticalTile = Domino.new(1, 2)
    tempVerticalTile.orientation = "vertical"
    tempVerticalTile.isMapTile = true
    
    local nodeWidth = Map.getMapTileDisplayWidth(tempNodeTile)
    local horizontalWidth = Map.getMapTileDisplayWidth(tempHorizontalTile)
    local levelSpacing = nodeWidth + 2 * horizontalWidth
    
    local targetX = UI.Layout.scale(60) + (map.currentNode.depth - 1) * levelSpacing
    -- Position node at 1/3 of screen width instead of center for better upcoming tile visibility
    local oneThirdScreen = screenWidth / 3
    local maxCameraX = math.max(0, map.totalWidth - screenWidth)
    local targetCameraX = targetX - oneThirdScreen
    
    -- Special case: if map is smaller than screen, center it instead of using 1/3 positioning
    if map.totalWidth <= screenWidth then
        targetCameraX = (map.totalWidth - screenWidth) / 2
    end
    
    -- Position camera to show current node at 1/3 screen width, but don't go beyond map bounds
    map.cameraX = math.max(0, math.min(maxCameraX, targetCameraX))
    map.cameraTargetX = map.cameraX -- Keep target in sync when not animating
end

-- Animate camera smoothly to position a target node at 1/3 of screen width
function Map.animateCameraTo(map, targetNodeDepth, screenWidth, duration, easing)
    duration = duration or 0.8
    easing = easing or "easeOutQuart"
    
    -- Safety checks for edge cases
    if not map or not map.currentNode or not screenWidth or screenWidth <= 0 then 
        return 
    end
    
    -- Additional safety: ensure targetNodeDepth is valid
    if not targetNodeDepth or targetNodeDepth < 1 then
        return
    end
    
    -- Calculate the same spacing as updateCamera
    local tempNodeTile = Domino.new(1, 1)
    tempNodeTile.orientation = "vertical"
    tempNodeTile.isMapTile = true
    
    local tempHorizontalTile = Domino.new(1, 2)
    tempHorizontalTile.orientation = "horizontal"
    tempHorizontalTile.isMapTile = true
    
    local nodeWidth = Map.getMapTileDisplayWidth(tempNodeTile)
    local horizontalWidth = Map.getMapTileDisplayWidth(tempHorizontalTile)
    local levelSpacing = nodeWidth + 2 * horizontalWidth
    
    -- Calculate target world position for the target node
    local targetWorldX = UI.Layout.scale(60) + (targetNodeDepth - 1) * levelSpacing
    
    -- Position node at 1/3 of screen width instead of center
    local oneThirdScreen = screenWidth / 3
    local targetCameraX = targetWorldX - oneThirdScreen
    
    -- Enforce camera bounds
    local maxCameraX = math.max(0, map.totalWidth - screenWidth)
    
    -- Special case: if map is smaller than screen, center it instead of using 1/3 positioning
    if map.totalWidth <= screenWidth then
        targetCameraX = (map.totalWidth - screenWidth) / 2
    end
    
    targetCameraX = math.max(0, math.min(maxCameraX, targetCameraX))
    
    -- Avoid unnecessary animation if we're already very close to the target
    local distanceThreshold = 5 -- pixels
    if math.abs(map.cameraX - targetCameraX) < distanceThreshold then
        map.cameraTargetX = targetCameraX
        return -- Skip animation for tiny movements
    end
    
    -- Store the target for reference
    map.cameraTargetX = targetCameraX
    
    -- Stop any existing camera animation
    if map.cameraAnimation then
        UI.Animation.stopAll(map)
        map.cameraAnimation = nil
    end
    
    -- Create smooth animation to the target position
    map.cameraAnimating = true
    map.cameraAnimation = UI.Animation.animateTo(map, {
        cameraX = targetCameraX
    }, duration, easing, function()
        -- Animation completed callback
        map.cameraAnimating = false
        map.cameraAnimation = nil
    end)
    
    return map.cameraAnimation
end

-- Generate domino tiles for map visualization using proper sprite system
function Map.generateMapTiles(map)
    map.tiles = {}
    
    -- Generate node tiles (vertical doubles at bifurcation points)
    for _, level in ipairs(map.levels) do
        for _, node in ipairs(level) do
            local nodeTile = Map.createNodeTile(node)
            table.insert(map.tiles, nodeTile)
            
            -- Store reference in node for easy access
            node.tile = nodeTile
        end
    end
    
    -- Generate path tiles (horizontal segments connecting nodes) using edge-to-edge logic
    Map.generatePathTiles(map)
    
    -- Apply proper positioning to all tiles
    Map.arrangeTilesWithProperSpacing(map)
    
    -- Sort all tiles by Y coordinate to ensure proper depth ordering
    -- Tiles with higher Y coordinates (lower rows) render on top of tiles with lower Y coordinates (upper rows)
    table.sort(map.tiles, function(a, b)
        return a.y < b.y
    end)
end

-- Create a domino tile for a node using proper sprite system
function Map.createNodeTile(node)
    local tileValue
    
    if node.nodeType == "start" then
        tileValue = {left = 0, right = 0} -- 0-0 for start (black double)
    elseif node.nodeType == "boss" or node.nodeType == "final" then
        tileValue = {left = 6, right = 6} -- 6-6 for boss (white double)
    else
        -- Use progressively higher doubles for regular nodes based on depth
        local value = math.min(6, math.max(1, node.depth - 1))
        tileValue = {left = value, right = value}
    end
    
    local tile = Domino.new(tileValue.left, tileValue.right)
    tile.isMapTile = true
    tile.mapNode = node
    tile.orientation = "vertical" -- Nodes are vertical doubles (bifurcations)
    tile.column = node.depth
    tile.lane = node.path
    tile.visible = true -- Node tiles are always visible
    
    -- Store world position for camera calculations
    tile.worldX = 0 -- Will be calculated during arrangement
    tile.worldY = 0
    tile.x = 0
    tile.y = 0
    
    return tile
end

-- Generate path tiles connecting nodes using proper domino chains
function Map.generatePathTiles(map)
    for nodeId, node in pairs(map.nodes) do
        for _, connectionId in ipairs(node.connections) do
            local targetNode = Map.findNodeById(map, connectionId)
            if targetNode then
                local pathTiles = Map.createPathTilesChain(map, node, targetNode)
                for _, pathTile in ipairs(pathTiles) do
                    table.insert(map.tiles, pathTile)
                end
            end
        end
    end
end

-- Create a continuous domino chain connecting two nodes
function Map.createPathTilesChain(map, fromNode, toNode)
    local pathTiles = {}
    
    -- Use varied domino values for paths (no doubles to distinguish from nodes)
    local pathValues = {{1,2}, {2,3}, {3,4}, {4,5}, {1,3}, {2,4}, {3,5}, {1,4}, {2,5}, {1,5}}
    
    -- Create appropriate path type based on node positions
    if fromNode.path == toNode.path then
        -- Same row - determine if adjacent or skip connection
        if toNode.depth == fromNode.depth + 1 then
            -- Same row, adjacent level - create straight horizontal chain
            pathTiles = Map.createHorizontalChain(fromNode, toNode, pathValues)
        else
            -- Same row, skip level - only use bridge if no intermediate nodes exist
            local hasIntermediateNodes = Map.hasIntermediateNodesInSameRow(map, fromNode, toNode)
            if not hasIntermediateNodes then
                pathTiles = Map.createBridgeChain(fromNode, toNode, pathValues)
            else
                -- Should not happen if DAG generation is correct - fall back to horizontal chain
                pathTiles = Map.createHorizontalChain(fromNode, toNode, pathValues)
            end
        end
    else
        -- Different lanes - create diagonal path with tile sequence
        pathTiles = Map.createDiagonalChain(fromNode, toNode, pathValues)
    end
    
    return pathTiles
end

-- Check if there are intermediate nodes in the same row between two nodes
function Map.hasIntermediateNodesInSameRow(map, fromNode, toNode)
    if fromNode.path ~= toNode.path then
        return false -- Different rows, not applicable
    end
    
    -- Check each level between fromNode and toNode for nodes in the same row
    for depth = fromNode.depth + 1, toNode.depth - 1 do
        if map.levels[depth] then
            for _, node in ipairs(map.levels[depth]) do
                if node.path == fromNode.path then
                    return true -- Found intermediate node in same row
                end
            end
        end
    end
    
    return false -- No intermediate nodes found
end

-- Create horizontal chain of domino tiles using edge-to-edge positioning and proper sprites
function Map.createHorizontalChain(fromNode, toNode, pathValues)
    local tiles = {}
    
    -- Calculate the gap we need to fill between nodes
    local gapDistance = math.abs(toNode.x - fromNode.x)
    
    -- Create a temporary tile to get accurate sprite dimensions
    local tempTile = Domino.new(1, 2)
    tempTile.orientation = "horizontal"
    local tileWidth = Map.getMapTileDisplayWidth(tempTile)
    
    -- Add small gap between tiles to prevent overlapping
    local tileGap = UI.Layout.scale(2)
    local tileSpacing = tileWidth + tileGap
    
    -- Always use exactly 2 horizontal tiles between nodes
    local numTiles = 2
    
    -- Calculate starting position to connect edge-to-edge with nodes
    local direction = toNode.x > fromNode.x and 1 or -1
    
    -- Get node tile width to calculate proper edge contact
    local tempNodeTile = Domino.new(1, 1)
    tempNodeTile.orientation = "vertical"
    tempNodeTile.isMapTile = true
    local nodeWidth = Map.getMapTileDisplayWidth(tempNodeTile)
    
    -- Position first path tile so its LEFT edge touches the RIGHT edge of source node
    -- For rightward paths: first tile's left edge at source node's right edge
    -- For leftward paths: first tile's right edge at source node's left edge
    local nodeEdgeOffset = nodeWidth / 2
    local pathTileHalfWidth = tileWidth / 2
    local startX
    if direction > 0 then
        -- Moving right: position first tile so its left edge is at source node's right edge
        -- Tile center = source node right edge + half tile width
        startX = fromNode.x + nodeEdgeOffset + pathTileHalfWidth
    else
        -- Moving left: position first tile so its right edge is at source node's left edge  
        -- Tile center = source node left edge - half tile width
        startX = fromNode.x - nodeEdgeOffset - pathTileHalfWidth
    end
    local y = fromNode.y
    
    -- Create a continuous domino chain with connecting values
    local chainValues = Map.generateConnectingChain(numTiles, pathValues)
    
    -- Create tiles with proper spacing
    for i = 1, numTiles do
        local tileValue = chainValues[i]
        
        local tile = Domino.new(tileValue[1], tileValue[2])
        tile.isMapTile = true
        tile.isPathTile = true
        tile.orientation = "horizontal" -- This will use titled sprites
        tile.fromNode = fromNode
        tile.toNode = toNode
        tile.visible = false -- Path tiles are hidden initially
        
        -- Position tiles with proper spacing to prevent overlap
        tile.worldX = startX + (i - 1) * tileSpacing * direction
        tile.worldY = y
        tile.x = tile.worldX
        tile.y = tile.worldY
        
        table.insert(tiles, tile)
    end
    
    return tiles
end

-- Create bridge chain of domino tiles for same-row skip connections (2H-1V-2H pattern)
function Map.createBridgeChain(fromNode, toNode, pathValues)
    local tiles = {}
    
    -- Create temporary tiles to get accurate sprite dimensions
    local tempHorizontalTile = Domino.new(1, 2)
    tempHorizontalTile.orientation = "horizontal"
    tempHorizontalTile.isMapTile = true
    local horizontalWidth = Map.getMapTileDisplayWidth(tempHorizontalTile)
    local horizontalHeight = Map.getMapTileDisplayHeight(tempHorizontalTile)
    
    local tempVerticalTile = Domino.new(1, 2)
    tempVerticalTile.orientation = "vertical"
    tempVerticalTile.isMapTile = true
    local verticalWidth = Map.getMapTileDisplayWidth(tempVerticalTile)
    local verticalHeight = Map.getMapTileDisplayHeight(tempVerticalTile)
    
    -- Get node tile width for edge positioning
    local tempNodeTile = Domino.new(1, 1)
    tempNodeTile.orientation = "vertical"
    tempNodeTile.isMapTile = true
    local nodeWidth = Map.getMapTileDisplayWidth(tempNodeTile)
    
    -- Generate connecting chain values for 5 tiles (4 horizontal + 1 vertical)
    local chainValues = Map.generateConnectingChain(5, pathValues)
    
    -- Position tiles edge-to-edge starting from destination node working backwards
    -- Pattern: [DestNode] ← [H1] ← [H2] ← [V] ← [H3] ← [H4] ← [SourceNode]
    local y = fromNode.y -- All tiles at same row level
    local destinationLeftEdge = toNode.x - nodeWidth / 2
    
    -- Tile 1: First horizontal (immediately left of destination node)
    local tile1 = Domino.new(chainValues[1][1], chainValues[1][2])
    tile1.isMapTile = true
    tile1.isPathTile = true
    tile1.orientation = "horizontal"
    tile1.fromNode = fromNode
    tile1.toNode = toNode
    tile1.visible = false -- Path tiles are hidden initially
    -- Position so right edge touches destination's left edge
    tile1.worldX = destinationLeftEdge - horizontalWidth / 2
    tile1.worldY = y
    tile1.x = tile1.worldX
    tile1.y = tile1.worldY
    table.insert(tiles, tile1)
    
    -- Tile 2: Second horizontal (left of first horizontal)
    local tile2 = Domino.new(chainValues[2][1], chainValues[2][2])
    tile2.isMapTile = true
    tile2.isPathTile = true
    tile2.orientation = "horizontal"
    tile2.fromNode = fromNode
    tile2.toNode = toNode
    tile2.visible = false -- Path tiles are hidden initially
    -- Position so right edge touches tile1's left edge
    local tile1LeftEdge = tile1.worldX - horizontalWidth / 2
    tile2.worldX = tile1LeftEdge - horizontalWidth / 2
    tile2.worldY = y
    tile2.x = tile2.worldX
    tile2.y = tile2.worldY
    table.insert(tiles, tile2)
    
    -- Tile 3: Vertical (left of second horizontal, slight downward offset)
    local tile3 = Domino.new(chainValues[3][1], chainValues[3][2])
    tile3.isMapTile = true
    tile3.isPathTile = true
    tile3.orientation = "vertical"
    tile3.fromNode = fromNode
    tile3.toNode = toNode
    tile3.visible = false -- Path tiles are hidden initially
    -- Position so right edge touches tile2's left edge
    local tile2LeftEdge = tile2.worldX - horizontalWidth / 2
    tile3.worldX = tile2LeftEdge - verticalWidth / 2
    tile3.worldY = y 
    tile3.x = tile3.worldX
    tile3.y = tile3.worldY
    table.insert(tiles, tile3)
    
    -- Tile 4: Third horizontal (left of vertical)
    local tile4 = Domino.new(chainValues[4][1], chainValues[4][2])
    tile4.isMapTile = true
    tile4.isPathTile = true
    tile4.orientation = "horizontal"
    tile4.fromNode = fromNode
    tile4.toNode = toNode
    tile4.visible = false -- Path tiles are hidden initially
    -- Position so right edge touches tile3's left edge
    local tile3LeftEdge = tile3.worldX - verticalWidth / 2
    tile4.worldX = tile3LeftEdge - horizontalWidth / 2
    tile4.worldY = y
    tile4.x = tile4.worldX
    tile4.y = tile4.worldY
    table.insert(tiles, tile4)
    
    -- Tile 5: Fourth horizontal (leftmost tile, should connect toward source node)
    local tile5 = Domino.new(chainValues[5][1], chainValues[5][2])
    tile5.isMapTile = true
    tile5.isPathTile = true
    tile5.orientation = "horizontal"
    tile5.fromNode = fromNode
    tile5.toNode = toNode
    tile5.visible = false -- Path tiles are hidden initially
    -- Position so right edge touches tile4's left edge
    local tile4LeftEdge = tile4.worldX - horizontalWidth / 2
    tile5.worldX = tile4LeftEdge - horizontalWidth / 2
    tile5.worldY = y
    tile5.x = tile5.worldX
    tile5.y = tile5.worldY
    table.insert(tiles, tile5)
    
    return tiles
end

-- Create diagonal chain of domino tiles for paths between different rows
function Map.createDiagonalChain(fromNode, toNode, pathValues)
    local tiles = {}
    
    -- Create temporary tiles to get accurate sprite dimensions
    local tempHorizontalTile = Domino.new(1, 2)
    tempHorizontalTile.orientation = "horizontal"
    tempHorizontalTile.isMapTile = true
    local horizontalWidth = Map.getMapTileDisplayWidth(tempHorizontalTile)
    local horizontalHeight = Map.getMapTileDisplayHeight(tempHorizontalTile)
    
    local tempVerticalTile = Domino.new(1, 2)
    tempVerticalTile.orientation = "vertical" 
    tempVerticalTile.isMapTile = true
    local verticalWidth = Map.getMapTileDisplayWidth(tempVerticalTile)
    local verticalHeight = Map.getMapTileDisplayHeight(tempVerticalTile)
    
    -- Get destination node tile width for edge positioning
    local tempNodeTile = Domino.new(1, 1)
    tempNodeTile.orientation = "vertical"
    tempNodeTile.isMapTile = true
    local nodeWidth = Map.getMapTileDisplayWidth(tempNodeTile)
    
    -- Add small gap between tiles to prevent overlapping
    local tileGap = UI.Layout.scale(2)
    
    -- Generate connecting chain values for 4 tiles (2 horizontal + 2 vertical)
    local chainValues = Map.generateConnectingChain(4, pathValues)
    
    -- Tile 1: Starting horizontal tile - extends to the right of the starting node
    local startingHorizontalTile = Domino.new(chainValues[1][1], chainValues[1][2])
    startingHorizontalTile.isMapTile = true
    startingHorizontalTile.isPathTile = true
    startingHorizontalTile.orientation = "horizontal"
    startingHorizontalTile.fromNode = fromNode
    startingHorizontalTile.toNode = toNode
    startingHorizontalTile.visible = false -- Path tiles are hidden initially
    
    -- Position so left edge touches source node's right edge
    local sourceRightEdge = fromNode.x + nodeWidth / 2
    startingHorizontalTile.worldX = sourceRightEdge + horizontalWidth / 2
    startingHorizontalTile.worldY = fromNode.y
    startingHorizontalTile.x = startingHorizontalTile.worldX
    startingHorizontalTile.y = startingHorizontalTile.worldY
    table.insert(tiles, startingHorizontalTile)
    
    -- Position tiles working backwards from destination node
    -- Starting from destination node's left edge
    local destinationLeftEdge = toNode.x - nodeWidth / 2
    
    -- Tile 2: Destination horizontal tile - its RIGHT edge touches destination node's LEFT edge
    local destinationHorizontalTile = Domino.new(chainValues[2][1], chainValues[2][2])
    destinationHorizontalTile.isMapTile = true
    destinationHorizontalTile.isPathTile = true
    destinationHorizontalTile.orientation = "horizontal"
    destinationHorizontalTile.fromNode = fromNode
    destinationHorizontalTile.toNode = toNode
    destinationHorizontalTile.visible = false -- Path tiles are hidden initially
    
    -- Position so right edge touches destination's left edge
    destinationHorizontalTile.worldX = destinationLeftEdge - horizontalWidth / 2
    destinationHorizontalTile.worldY = toNode.y
    destinationHorizontalTile.x = destinationHorizontalTile.worldX
    destinationHorizontalTile.y = destinationHorizontalTile.worldY
    table.insert(tiles, destinationHorizontalTile)
    
    -- Tile 3: First vertical tile - its RIGHT edge touches destination horizontal tile's LEFT edge
    local firstVerticalTile = Domino.new(chainValues[3][1], chainValues[3][2])
    firstVerticalTile.isMapTile = true
    firstVerticalTile.isPathTile = true
    firstVerticalTile.orientation = "vertical"
    firstVerticalTile.fromNode = fromNode
    firstVerticalTile.toNode = toNode
    firstVerticalTile.visible = false -- Path tiles are hidden initially
    
    -- Position so right edge touches destination horizontal tile's left edge
    local destinationHorizontalLeftEdge = destinationHorizontalTile.worldX - horizontalWidth / 2
    firstVerticalTile.worldX = destinationHorizontalLeftEdge - verticalWidth / 2
    
    -- Detect diagonal direction for different vertical tile positioning
    local isUpDiagonal = fromNode.path < toNode.path
    
    if isUpDiagonal then
        -- For up diagonals: position vertical tiles upward with total offset of 2 tile heights
        firstVerticalTile.worldY = toNode.y - verticalHeight * 0.32
    else
        -- For down diagonals: position vertical tiles downward by 1/3 tile height + half tile height offset
        firstVerticalTile.worldY = toNode.y + verticalHeight * 0.32
    end
    
    firstVerticalTile.x = firstVerticalTile.worldX
    firstVerticalTile.y = firstVerticalTile.worldY
    
    -- Tile 4: Second vertical tile - positioned relative to the first vertical tile
    local secondVerticalTile = Domino.new(chainValues[4][1], chainValues[4][2])
    secondVerticalTile.isMapTile = true
    secondVerticalTile.isPathTile = true
    secondVerticalTile.orientation = "vertical"
    secondVerticalTile.fromNode = fromNode
    secondVerticalTile.toNode = toNode
    secondVerticalTile.visible = false -- Path tiles are hidden initially
    
    -- Position overlapping with the first vertical tile for better visual connection
    secondVerticalTile.worldX = firstVerticalTile.worldX
    
    if isUpDiagonal then
        -- For up diagonals: continue upward positioning (total 2 tile height offset)
        secondVerticalTile.worldY = firstVerticalTile.worldY - verticalHeight * 0.9
    else
        -- For down diagonals: continue downward positioning (original behavior)
        secondVerticalTile.worldY = firstVerticalTile.worldY + verticalHeight * 0.9
    end
    secondVerticalTile.x = secondVerticalTile.worldX
    secondVerticalTile.y = secondVerticalTile.worldY
    
    -- Insert tiles in depth-sorted order: tiles with higher Y coordinates (lower rows) render on top
    if isUpDiagonal then
        -- For up diagonals: secondVertical has lower Y (upper row), firstVertical has higher Y (lower row)
        -- Insert secondVertical first (renders behind), then firstVertical (renders on top)
        table.insert(tiles, secondVerticalTile)
        table.insert(tiles, firstVerticalTile)
    else
        -- For down diagonals: firstVertical has lower Y (upper row), secondVertical has higher Y (lower row)  
        -- Insert firstVertical first (renders behind), then secondVertical (renders on top)
        table.insert(tiles, firstVerticalTile)
        table.insert(tiles, secondVerticalTile)
    end
    
    return tiles
end

-- Generate a connecting domino chain where each tile connects to the next
function Map.generateConnectingChain(numTiles, pathValues)
    local chain = {}
    
    if numTiles <= 0 then
        return chain
    end
    
    -- Start with a random tile from available values
    local startTile = pathValues[love.math.random(1, #pathValues)]
    table.insert(chain, {startTile[1], startTile[2]})
    
    -- For each subsequent tile, ensure it connects to the previous one
    for i = 2, numTiles do
        local connectingValue = chain[i-1][2] -- Right side of previous tile
        
        -- Find a tile that can connect (left side matches previous right side)
        local nextTile = nil
        for _, value in ipairs(pathValues) do
            if value[1] == connectingValue then
                nextTile = {value[1], value[2]}
                break
            elseif value[2] == connectingValue then
                -- Flip the tile to make it connect
                nextTile = {value[2], value[1]}
                break
            end
        end
        
        -- If no connecting tile found, create one that connects
        if not nextTile then
            local randomRight = love.math.random(1, 6)
            nextTile = {connectingValue, randomRight}
        end
        
        table.insert(chain, nextTile)
    end
    
    return chain
end

-- Check if two paths would cross each other
function Map.wouldPathsCross(fromLane1, toLane1, existingPaths)
    for _, path in ipairs(existingPaths) do
        local fromLane2 = path.fromLane
        local toLane2 = path.toLane
        
        -- Check if the paths would intersect
        -- Two paths cross if one goes "over" the other
        local path1GoesUp = toLane1 > fromLane1
        local path1GoesDown = toLane1 < fromLane1
        local path2GoesUp = toLane2 > fromLane2
        local path2GoesDown = toLane2 < fromLane2
        
        -- Paths cross if they have opposite directions and overlap in range
        if (path1GoesUp and path2GoesDown) or (path1GoesDown and path2GoesUp) then
            local minLane1 = math.min(fromLane1, toLane1)
            local maxLane1 = math.max(fromLane1, toLane1)
            local minLane2 = math.min(fromLane2, toLane2)
            local maxLane2 = math.max(fromLane2, toLane2)
            
            -- Check if ranges overlap
            if not (maxLane1 < minLane2 or maxLane2 < minLane1) then
                return true -- Paths would cross
            end
        end
    end
    
    return false -- No crossing detected
end

-- TODO: L-shape intermediate point calculation will be implemented later

-- Get display width for map tiles (similar to Board.getTileDisplayWidth but for map scale)
function Map.getMapTileDisplayWidth(tile)
    -- Get the appropriate sprite for this domino
    local leftVal, rightVal = tile.left, tile.right
    local minVal = math.min(leftVal, rightVal)
    local maxVal = math.max(leftVal, rightVal)
    local spriteKey = minVal .. maxVal
    
    local spriteData
    if tile.orientation == "horizontal" then
        -- Use tilted sprites for horizontal path tiles
        local tiltedKey = leftVal .. rightVal
        spriteData = dominoTiltedSprites and dominoTiltedSprites[tiltedKey]
    else
        -- Use vertical sprites for node tiles
        spriteData = dominoSprites and dominoSprites[spriteKey]
    end
    
    if spriteData and spriteData.sprite then
        local sprite = spriteData.sprite
        
        if sprite and sprite.getWidth then
            -- Use same base scaling as main game but scale for map
            local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
            local spriteScale = math.max(minScale * 1.2, 0.8) -- Smaller than main game but larger than current tiny tiles
            
            local renderedWidth = sprite:getWidth() * spriteScale
            return renderedWidth
        end
    end
    
    -- Fallback to layout system
    local tileWidth, _ = UI.Layout.getTileSize()
    return tileWidth * 0.8
end

-- Get display height for map tiles
function Map.getMapTileDisplayHeight(tile)
    -- Similar logic but for height
    local leftVal, rightVal = tile.left, tile.right
    local minVal = math.min(leftVal, rightVal)
    local maxVal = math.max(leftVal, rightVal)
    local spriteKey = minVal .. maxVal
    
    local spriteData
    if tile.orientation == "horizontal" then
        local tiltedKey = leftVal .. rightVal
        spriteData = dominoTiltedSprites and dominoTiltedSprites[tiltedKey]
    else
        spriteData = dominoSprites and dominoSprites[spriteKey]
    end
    
    if spriteData and spriteData.sprite then
        local sprite = spriteData.sprite
        
        if sprite and sprite.getHeight then
            local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
            local spriteScale = math.max(minScale * 1.2, 0.8)
            
            local renderedHeight = sprite:getHeight() * spriteScale
            return renderedHeight
        end
    end
    
    -- Fallback
    local _, tileHeight = UI.Layout.getTileSize()
    return tileHeight * 0.8
end

-- Calculate the number of nodes in each possible path from start to boss
function Map.calculatePathLengths(map)
    local startNode = nil
    local bossNode = nil
    
    -- Find start and boss nodes
    for _, node in pairs(map.nodes) do
        if node.nodeType == "start" then
            startNode = node
        elseif node.nodeType == "boss" then
            bossNode = node
        end
    end
    
    if not startNode or not bossNode then
        return {}
    end
    
    -- Find all possible paths from start to boss using DFS
    local allPaths = {}
    
    local function findPaths(currentNode, currentPath, visited)
        -- Add current node to path
        local newPath = {}
        for _, nodeId in ipairs(currentPath) do
            table.insert(newPath, nodeId)
        end
        table.insert(newPath, currentNode.id)
        
        -- Mark as visited for this path
        local newVisited = {}
        for k, v in pairs(visited) do
            newVisited[k] = v
        end
        newVisited[currentNode.id] = true
        
        -- If we reached the boss, add this complete path
        if currentNode.id == bossNode.id then
            table.insert(allPaths, newPath)
            return
        end
        
        -- Continue exploring connections
        for _, connectionId in ipairs(currentNode.connections) do
            if not newVisited[connectionId] then
                local nextNode = map.nodes[connectionId]
                if nextNode then
                    findPaths(nextNode, newPath, newVisited)
                end
            end
        end
    end
    
    findPaths(startNode, {}, {})
    
    -- Calculate path lengths and statistics
    local pathLengths = {}
    local totalLength = 0
    for i, path in ipairs(allPaths) do
        pathLengths[i] = #path
        totalLength = totalLength + #path
    end
    
    local averageLength = #allPaths > 0 and totalLength / #allPaths or 0
    
    -- Handle empty pathLengths case
    local minLength = 0
    local maxLength = 0
    if #pathLengths > 0 then
        -- Use table.unpack for Lua 5.2+ compatibility, fallback to unpack for Lua 5.1
        local unpackFunc = table.unpack or unpack
        minLength = math.min(unpackFunc(pathLengths))
        maxLength = math.max(unpackFunc(pathLengths))
    end
    
    return {
        paths = allPaths,
        lengths = pathLengths,
        averageLength = averageLength,
        minLength = minLength,
        maxLength = maxLength
    }
end

-- Score a potential connection based on how it affects path balance
function Map.getPathBalanceScore(map, sourceNode, targetNode, currentPathLengths)
    -- Create a temporary map with the proposed connection
    local tempConnections = {}
    for _, connectionId in ipairs(sourceNode.connections) do
        table.insert(tempConnections, connectionId)
    end
    table.insert(tempConnections, targetNode.id)
    
    -- Calculate what the path lengths would be with this connection
    local originalConnections = sourceNode.connections
    sourceNode.connections = tempConnections
    local newPathLengths = Map.calculatePathLengths(map)
    sourceNode.connections = originalConnections
    
    -- Score based on balance improvement
    local score = 0
    
    -- Prefer connections that reduce the variance in path lengths
    if #newPathLengths.lengths > 0 and #currentPathLengths.lengths > 0 then
        local oldVariance = 0
        local newVariance = 0
        
        -- Calculate old variance
        for _, length in ipairs(currentPathLengths.lengths) do
            local diff = length - currentPathLengths.averageLength
            oldVariance = oldVariance + diff * diff
        end
        oldVariance = oldVariance / #currentPathLengths.lengths
        
        -- Calculate new variance
        for _, length in ipairs(newPathLengths.lengths) do
            local diff = length - newPathLengths.averageLength
            newVariance = newVariance + diff * diff
        end
        newVariance = newVariance / #newPathLengths.lengths
        
        -- Higher score for reduced variance (better balance)
        score = oldVariance - newVariance
    end
    
    -- Bonus for same-row connections (they provide alternate routes)
    if sourceNode.path == targetNode.path then
        score = score + 10
    end
    
    -- Bonus for connections that create more path options
    if #newPathLengths.paths > #currentPathLengths.paths then
        score = score + 5
    end
    
    return score
end

-- Validate and improve path balance across all possible routes
function Map.validatePathBalance(map)
    local pathInfo = Map.calculatePathLengths(map)
    
    -- Check if we have valid paths
    if #pathInfo.lengths == 0 then
        print("Warning: No valid paths found during balance validation")
        return
    end
    
    -- Calculate balance metrics
    local variance = 0
    for _, length in ipairs(pathInfo.lengths) do
        local diff = length - pathInfo.averageLength
        variance = variance + diff * diff
    end
    variance = variance / #pathInfo.lengths
    
    local lengthRange = pathInfo.maxLength - pathInfo.minLength
    local balanceThreshold = 3 -- Maximum acceptable difference between shortest and longest path
    
    print(string.format("Path balance: %d paths, lengths %d-%d (avg %.1f), variance %.1f", 
          #pathInfo.paths, pathInfo.minLength, pathInfo.maxLength, pathInfo.averageLength, variance))
    
    -- If paths are reasonably balanced, no action needed
    if lengthRange <= balanceThreshold then
        print("Path balance acceptable")
        return
    end
    
    print(string.format("Path imbalance detected (range %d > threshold %d), attempting to improve...", 
          lengthRange, balanceThreshold))
    
    -- Attempt to improve balance by adding strategic connections
    Map.improvePathBalance(map, pathInfo)
    
    -- Recalculate and report final balance
    local finalPathInfo = Map.calculatePathLengths(map)
    local finalRange = finalPathInfo.maxLength - finalPathInfo.minLength
    print(string.format("Final path balance: %d paths, lengths %d-%d (range %d)", 
          #finalPathInfo.paths, finalPathInfo.minLength, finalPathInfo.maxLength, finalRange))
end

-- Attempt to improve path balance by adding strategic connections
function Map.improvePathBalance(map, pathInfo)
    local numLevels = #map.levels
    local maxAttempts = 10
    local attempts = 0
    
    while attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Find nodes that could benefit from additional connections
        local improvementMade = false
        
        for depth = 1, numLevels - 1 do
            local currentLevel = map.levels[depth]
            
            for _, node in ipairs(currentLevel) do
                -- Skip if node already has maximum connections or is a commitment point
                if #node.connections >= 4 or Map.shouldBeCommitmentPoint(depth, numLevels, node) then
                    goto continue
                end
                
                -- Look for beneficial connections using new connection rules
                local candidates = {}
                
                -- Check both adjacent level and 1-skip level candidates, respecting constraints
                for targetDepth = depth + 1, math.min(numLevels, depth + 2) do
                    if map.levels[targetDepth] then
                        for _, targetNode in ipairs(map.levels[targetDepth]) do
                            -- Check if not already connected
                            local alreadyConnected = false
                            for _, connId in ipairs(node.connections) do
                                if connId == targetNode.id then
                                    alreadyConnected = true
                                    break
                                end
                            end
                            
                            -- Use the new validation function to check if this connection is valid
                            if not alreadyConnected and Map.isValidConnection(node, targetNode, map) then
                                table.insert(candidates, targetNode)
                            end
                        end
                    end
                end
                
                -- Evaluate candidates for balance improvement
                local bestCandidate = nil
                local bestScore = -999
                
                for _, candidate in ipairs(candidates) do
                    local score = Map.getPathBalanceScore(map, node, candidate, pathInfo)
                    if score > bestScore then
                        bestScore = score
                        bestCandidate = candidate
                    end
                end
                
                -- Add the best connection if it significantly improves balance
                if bestCandidate and bestScore > 5 then
                    table.insert(node.connections, bestCandidate.id)
                    improvementMade = true
                    print(string.format("Added balance connection: %s -> %s (score %.1f)", 
                          node.id, bestCandidate.id, bestScore))
                end
                
                ::continue::
            end
        end
        
        -- If no improvement was made, stop trying
        if not improvementMade then
            break
        end
        
        -- Recalculate path info for next iteration
        pathInfo = Map.calculatePathLengths(map)
        local currentRange = pathInfo.maxLength - pathInfo.minLength
        
        -- If balance is now acceptable, stop
        if currentRange <= 3 then
            print(string.format("Path balance improved sufficiently after %d attempts", attempts))
            break
        end
    end
end

-- Arrange all tiles with proper spacing and positioning
function Map.arrangeTilesWithProperSpacing(map)
    -- First, arrange nodes in their calculated positions
    for _, level in ipairs(map.levels) do
        for _, node in ipairs(level) do
            if node.tile then
                -- Node positions are calculated by Map.calculateNodePositions()
                -- Store as world positions for camera system
                node.tile.worldX = node.x
                node.tile.worldY = node.y
                node.tile.x = node.x
                node.tile.y = node.y
            end
        end
    end
    
    -- Path tiles are already positioned by the chain creation functions
    -- No additional arrangement needed as they use edge-to-edge logic
end

-- Update path tile visibility based on specific connections traversed
function Map.updatePathVisibility(map)
    if not map.tiles then return end
    
    -- Iterate through all tiles and update path tile visibility
    for _, tile in ipairs(map.tiles) do
        if tile.isPathTile and tile.fromNode and tile.toNode then
            -- Path tiles are visible only if this specific connection was actually traversed
            -- This shows only the exact path the player took, not all possible paths
            local fromNodeId = tile.fromNode.id
            local toNodeId = tile.toNode.id
            
            tile.visible = (map.traversedConnections[fromNodeId] and 
                           map.traversedConnections[fromNodeId][toNodeId]) or false
        end
    end
end

-- Perform comprehensive final connectivity check
function Map.performFinalConnectivityCheck(map)
    print("Performing final connectivity validation...")
    
    -- Find start and boss nodes
    local startNode = nil
    local bossNode = nil
    for _, node in pairs(map.nodes) do
        if node.nodeType == "start" then
            startNode = node
        elseif node.nodeType == "boss" then
            bossNode = node
        end
    end
    
    if not startNode or not bossNode then
        print("ERROR: Missing start or boss node")
        return false
    end
    
    -- Check 1: Boss must have incoming connections
    local bossHasIncoming = false
    for nodeId, node in pairs(map.nodes) do
        if nodeId ~= bossNode.id then
            for _, connectionId in ipairs(node.connections) do
                if connectionId == bossNode.id then
                    bossHasIncoming = true
                    break
                end
            end
            if bossHasIncoming then break end
        end
    end
    
    if not bossHasIncoming then
        print("ERROR: Boss node has no incoming connections")
        return false
    end
    
    -- Check 2: Forward reachability from start
    local reachableFromStart = Map.getReachableNodes(map, startNode)
    if not reachableFromStart[bossNode.id] then
        print("ERROR: Boss is not reachable from start")
        return false
    end
    
    -- Check 3: Every node must be reachable from start
    local totalNodes = 0
    local reachableNodes = 0
    for nodeId, _ in pairs(map.nodes) do
        totalNodes = totalNodes + 1
        if reachableFromStart[nodeId] then
            reachableNodes = reachableNodes + 1
        else
            print("ERROR: Node " .. nodeId .. " is not reachable from start")
        end
    end
    
    if reachableNodes ~= totalNodes then
        print("ERROR: " .. (totalNodes - reachableNodes) .. " nodes are unreachable from start")
        return false
    end
    
    -- Check 4: Every node must have a path to boss (backward reachability)
    local canReachBoss = Map.getNodesCanReachBoss(map, bossNode)
    local nodesCanReachBoss = 0
    for nodeId, _ in pairs(map.nodes) do
        if canReachBoss[nodeId] then
            nodesCanReachBoss = nodesCanReachBoss + 1
        else
            print("ERROR: Node " .. nodeId .. " cannot reach boss")
        end
    end
    
    if nodesCanReachBoss ~= totalNodes then
        print("ERROR: " .. (totalNodes - nodesCanReachBoss) .. " nodes cannot reach boss")
        return false
    end
    
    -- Check 5: Ensure we have at least one complete path from start to boss
    local pathCount = Map.calculatePathLengths(map)
    if #pathCount.paths == 0 then
        print("ERROR: No complete paths from start to boss")
        return false
    end
    
    print("Final connectivity validation PASSED: " .. totalNodes .. " nodes, " .. #pathCount.paths .. " complete paths")
    return true
end

-- Get all nodes reachable from a given node (forward direction)
function Map.getReachableNodes(map, startNode)
    local reachable = {}
    local toVisit = {startNode.id}
    
    while #toVisit > 0 do
        local currentId = table.remove(toVisit, 1)
        if not reachable[currentId] then
            reachable[currentId] = true
            local currentNode = map.nodes[currentId]
            if currentNode then
                for _, connectionId in ipairs(currentNode.connections) do
                    if not reachable[connectionId] then
                        table.insert(toVisit, connectionId)
                    end
                end
            end
        end
    end
    
    return reachable
end

-- Get all nodes that can reach the boss (backward reachability)
function Map.getNodesCanReachBoss(map, bossNode)
    local canReachBoss = {[bossNode.id] = true}
    local changed = true
    
    -- Keep iterating until no more nodes are marked as able to reach boss
    while changed do
        changed = false
        for nodeId, node in pairs(map.nodes) do
            if not canReachBoss[nodeId] then
                -- Check if any of this node's connections can reach boss
                for _, connectionId in ipairs(node.connections) do
                    if canReachBoss[connectionId] then
                        canReachBoss[nodeId] = true
                        changed = true
                        break
                    end
                end
            end
        end
    end
    
    return canReachBoss
end

-- Analyze all possible paths and count combat nodes in each
function Map.analyzePathCombatCounts(map)
    local startNode = nil
    local bossNode = nil
    
    -- Find start and boss nodes
    for _, node in pairs(map.nodes) do
        if node.nodeType == "start" then
            startNode = node
        elseif node.nodeType == "boss" then
            bossNode = node
        end
    end
    
    if not startNode or not bossNode then
        return {paths = {}, combatCounts = {}, deficientPaths = {}}
    end
    
    -- Find all possible paths from start to boss using DFS
    local allPaths = {}
    
    local function findPaths(currentNode, currentPath, visited)
        -- Add current node to path
        local newPath = {}
        for _, nodeId in ipairs(currentPath) do
            table.insert(newPath, nodeId)
        end
        table.insert(newPath, currentNode.id)
        
        -- Mark as visited for this path
        local newVisited = {}
        for k, v in pairs(visited) do
            newVisited[k] = v
        end
        newVisited[currentNode.id] = true
        
        -- If we reached the boss, add this complete path
        if currentNode.id == bossNode.id then
            table.insert(allPaths, newPath)
            return
        end
        
        -- Continue exploring connections
        for _, connectionId in ipairs(currentNode.connections) do
            if not newVisited[connectionId] then
                local nextNode = map.nodes[connectionId]
                if nextNode then
                    findPaths(nextNode, newPath, newVisited)
                end
            end
        end
    end
    
    findPaths(startNode, {}, {})
    
    -- Count combat nodes in each path (excluding start and boss)
    local combatCounts = {}
    local deficientPaths = {}
    local minCombatRequired = 3
    
    for i, path in ipairs(allPaths) do
        local combatCount = 0
        
        -- Count combat nodes, excluding start and boss nodes
        for j = 2, #path - 1 do  -- Skip start (index 1) and boss (last index)
            local nodeId = path[j]
            local node = map.nodes[nodeId]
            if node and node.nodeType == "combat" then
                combatCount = combatCount + 1
            end
        end
        
        combatCounts[i] = combatCount
        
        -- Track paths that don't meet minimum combat requirement
        if combatCount < minCombatRequired then
            table.insert(deficientPaths, {
                pathIndex = i,
                path = path,
                combatCount = combatCount,
                deficit = minCombatRequired - combatCount
            })
        end
    end
    
    return {
        paths = allPaths,
        combatCounts = combatCounts,
        deficientPaths = deficientPaths,
        minCombatRequired = minCombatRequired
    }
end

-- Validate that all paths have at least 3 combat nodes
function Map.validateCombatRequirements(map)
    local pathAnalysis = Map.analyzePathCombatCounts(map)
    
    if #pathAnalysis.deficientPaths == 0 then
        print(string.format("Combat requirements PASSED: All %d paths have %d+ combat nodes", 
              #pathAnalysis.paths, pathAnalysis.minCombatRequired))
        return true
    end
    
    print(string.format("Combat requirements FAILED: %d of %d paths have insufficient combat nodes", 
          #pathAnalysis.deficientPaths, #pathAnalysis.paths))
    
    for _, defPath in ipairs(pathAnalysis.deficientPaths) do
        print(string.format("  Path %d: %d combat nodes (need %d more)", 
              defPath.pathIndex, defPath.combatCount, defPath.deficit))
    end
    
    return false
end

-- Correct combat deficiency by converting strategic nodes to combat type
function Map.correctCombatDeficiency(map)
    local pathAnalysis = Map.analyzePathCombatCounts(map)
    
    if #pathAnalysis.deficientPaths == 0 then
        return true -- Already satisfies requirements
    end
    
    print(string.format("Correcting combat deficiency in %d paths...", #pathAnalysis.deficientPaths))
    
    -- Find candidate nodes for conversion (exclude start, boss, and already combat nodes)
    local conversionCandidates = {}
    
    for _, defPath in ipairs(pathAnalysis.deficientPaths) do
        for j = 2, #defPath.path - 1 do  -- Skip start and boss
            local nodeId = defPath.path[j]
            local node = map.nodes[nodeId]
            
            if node and node.nodeType ~= "combat" and node.nodeType ~= "start" and node.nodeType ~= "boss" then
                if not conversionCandidates[nodeId] then
                    conversionCandidates[nodeId] = {
                        node = node,
                        pathCount = 0,
                        totalDeficit = 0,
                        affectedPaths = {}
                    }
                end
                
                conversionCandidates[nodeId].pathCount = conversionCandidates[nodeId].pathCount + 1
                conversionCandidates[nodeId].totalDeficit = conversionCandidates[nodeId].totalDeficit + defPath.deficit
                table.insert(conversionCandidates[nodeId].affectedPaths, defPath.pathIndex)
            end
        end
    end
    
    -- Sort candidates by impact (prefer nodes that fix multiple deficient paths)
    local sortedCandidates = {}
    for nodeId, candidate in pairs(conversionCandidates) do
        table.insert(sortedCandidates, {nodeId = nodeId, candidate = candidate})
    end
    
    table.sort(sortedCandidates, function(a, b)
        -- Primary: prefer nodes that affect more deficient paths
        if a.candidate.pathCount ~= b.candidate.pathCount then
            return a.candidate.pathCount > b.candidate.pathCount
        end
        -- Secondary: prefer nodes with higher total deficit impact
        return a.candidate.totalDeficit > b.candidate.totalDeficit
    end)
    
    -- Convert nodes to combat type until requirements are met
    local conversionsNeeded = 0
    for _, defPath in ipairs(pathAnalysis.deficientPaths) do
        conversionsNeeded = math.max(conversionsNeeded, defPath.deficit)
    end
    
    local conversions = 0
    for _, candidateInfo in ipairs(sortedCandidates) do
        if conversions >= conversionsNeeded then
            break
        end
        
        local nodeId = candidateInfo.nodeId
        local node = candidateInfo.candidate.node
        local oldType = node.nodeType
        
        -- Convert to combat type
        node.nodeType = "combat"
        conversions = conversions + 1
        
        print(string.format("Converted %s from %s to combat (affects %d deficient paths)", 
              nodeId, oldType, candidateInfo.candidate.pathCount))
        
        -- Check if we've satisfied all requirements
        local newAnalysis = Map.analyzePathCombatCounts(map)
        if #newAnalysis.deficientPaths == 0 then
            print(string.format("Combat requirements satisfied after %d conversions", conversions))
            return true
        end
    end
    
    -- Final check
    local finalAnalysis = Map.analyzePathCombatCounts(map)
    if #finalAnalysis.deficientPaths == 0 then
        print(string.format("Combat requirements satisfied after %d conversions", conversions))
        return true
    else
        print(string.format("WARNING: Still have %d deficient paths after %d conversions", 
              #finalAnalysis.deficientPaths, conversions))
        return false
    end
end

-- Path Preview Animation System
-- Generate preview path tiles between two nodes for animation
function Map.generatePreviewPath(map, fromNode, toNode)
    if not fromNode or not toNode then
        return {}
    end
    
    -- Clear any existing preview
    Map.clearPreviewPath(map)
    
    -- Generate temporary path tiles (similar to createPathTilesChain but marked as preview)
    local pathTiles = Map.createPathTilesChain(map, fromNode, toNode)
    
    -- Mark tiles as preview tiles and set initial animation state
    for i, tile in ipairs(pathTiles) do
        tile.isPreviewTile = true
        tile.previewIndex = i -- For staggered animation timing
        tile.opacity = 0 -- Start invisible
        tile.scale = 0.8 -- Start slightly smaller
        tile.animationProgress = 0
        tile.visible = true -- Will be rendered but starts transparent
        
        -- Special timing for L-shaped paths: delay the destination connecting tile
        if fromNode.path ~= toNode.path and i == 2 then
            -- This is the destination horizontal tile in a diagonal chain - delay it for L-shape effect
            tile.isLShapeCornerTile = true
        end
    end
    
    -- Store preview tiles in map
    map.previewTiles = pathTiles
    
    return pathTiles
end

-- Clear current preview path and stop animations
function Map.clearPreviewPath(map)
    if map.previewTiles then
        -- Animate out existing preview tiles
        for _, tile in ipairs(map.previewTiles) do
            if tile.animationProgress > 0 then
                -- Quickly fade out any visible tiles
                UI.Animation.animateTo(tile, {
                    opacity = 0,
                    scale = 0.8
                }, 0.2, "easeOutQuart", function()
                    tile.visible = false
                end)
            end
        end
    end
    
    map.previewTiles = {}
end

-- Animate preview path tiles with satisfying left-to-right sequence
function Map.animatePathPreview(map, direction)
    direction = direction or "in" -- "in" or "out"
    
    if not map.previewTiles or #map.previewTiles == 0 then
        return
    end
    
    local animationDelay = 0.08 -- Slightly faster for more satisfying flow
    local animationDuration = 0.4 -- Slightly longer for more pronounced effect
    
    for i, tile in ipairs(map.previewTiles) do
        local delay = (i - 1) * animationDelay
        
        -- Special timing for L-shaped corner tiles
        if tile.isLShapeCornerTile then
            delay = delay + animationDelay * 1.5 -- Extra delay for corner turn effect
        end
        
        if direction == "in" then
            -- Animate tiles appearing left to right with extra bounce
            local animation = UI.Animation.animateTo(tile, {
                opacity = 1,
                scale = 1.0,
                animationProgress = 1
            }, animationDuration, "easeOutBack")
            
            -- Add delay for staggered effect
            animation.elapsed = -delay
            
        else
            -- Animate tiles disappearing (reverse order for right to left)
            local reverseDelay = (#map.previewTiles - i) * (animationDelay * 0.5)
            local animation = UI.Animation.animateTo(tile, {
                opacity = 0,
                scale = 0.8,
                animationProgress = 0
            }, animationDuration * 0.7, "easeOutQuart", function()
                tile.visible = false
            end)
            
            animation.elapsed = -reverseDelay
        end
    end
end

-- Update preview path for a newly selected node
function Map.updatePreviewPath(map, selectedNodeId)
    if not selectedNodeId or not map.currentNode then
        Map.clearPreviewPath(map)
        return
    end
    
    local targetNode = Map.findNodeById(map, selectedNodeId)
    if not targetNode then
        Map.clearPreviewPath(map)
        return
    end
    
    -- Only show preview if node is available for selection
    if not Map.isNodeAvailable(map, selectedNodeId) then
        Map.clearPreviewPath(map)
        return
    end
    
    -- Generate new preview path
    local previewTiles = Map.generatePreviewPath(map, map.currentNode, targetNode)
    
    -- Start the satisfying left-to-right animation
    Map.animatePathPreview(map, "in")
end

return Map