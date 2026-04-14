function love.load()
	SCREEN_WIDTH = 900
	SCREEN_HEIGHT = 600

	TABLE_WIDTH = 0.6*SCREEN_WIDTH
	TABLE_HEIGHT = 0.85*SCREEN_HEIGHT
	
	BALL_COUNT = 16
	
	CUE_LENGTH = 15
	
	centerX, centerY = SCREEN_WIDTH/2, SCREEN_HEIGHT/2

	world = love.physics.newWorld(0, 0, true)
	objects = {} 
	-- table
	objects.table = {}
    -- One static body in the center
    objects.table.body = love.physics.newBody(world, SCREEN_WIDTH/2, SCREEN_HEIGHT/2, "static")

    local wallThickness = 10
    local w, h = TABLE_WIDTH, TABLE_HEIGHT

    -- Create 4 distinct shapes with offsets
    -- newRectangleShape(local_x, local_y, width, height)
    local shapes = {
        top    = love.physics.newRectangleShape(0, -h/2, w, wallThickness),
        bottom = love.physics.newRectangleShape(0, h/2, w, wallThickness),
        left   = love.physics.newRectangleShape(-w/2, 0, wallThickness, h),
        right  = love.physics.newRectangleShape(w/2, 0, wallThickness, h)
    }

    -- Attach each shape as a separate fixture
    for name, shape in pairs(shapes) do
        local fixt = love.physics.newFixture(objects.table.body, shape)
		fixt:setRestitution(1.0)
    end
	
	-- ball
	objects.balls = {}
	
	local margin = wallThickness + 10 
    local minX = centerX - (TABLE_WIDTH / 2) + margin
    local maxX = centerX + (TABLE_WIDTH / 2) - margin
    local minY = centerY - (TABLE_HEIGHT / 2) + margin
    local maxY = centerY + (TABLE_HEIGHT / 2) - margin
    
    for i = 1, BALL_COUNT do
        local ball = {}
        ball.radius = 10 -- Slightly larger for visibility
        
        -- Pick a random position within the table's interior
        local spawnX = math.random(minX, maxX)
        local spawnY = math.random(minY, maxY)
        
        ball.body = love.physics.newBody(world, spawnX, spawnY, "dynamic")
        ball.body:setLinearDamping(0.7) -- Friction so they eventually stop
        ball.shape = love.physics.newCircleShape(ball.radius)
        ball.fixture = love.physics.newFixture(ball.body, ball.shape, 1)
        ball.fixture:setRestitution(1.0) -- Make them bouncy
        
        table.insert(objects.balls, ball)
    end
	

	love.graphics.setBackgroundColor(24/255, 24/255, 24/255)
	love.window.setMode(SCREEN_WIDTH, SCREEN_HEIGHT)
  
end

function love.update(dt)
	world:update(dt)
end

function love.draw()
    love.graphics.setColor(0.28, 0.63, 0.05)
	
    -- Get all fixtures attached to the table body
    local fixtures = objects.table.body:getFixtures()
    
    for _, fixture in ipairs(fixtures) do
        local shape = fixture:getShape()
        -- Draw each shape using its world coordinates
        love.graphics.polygon("fill", objects.table.body:getWorldPoints(shape:getPoints()))
    end

    -- Draw the balls
    for _, b in ipairs(objects.balls) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", b.body:getX(), b.body:getY(), b.shape:getRadius())
		local x, y = love.mouse.getPosition()
		if checkCollision(x, y, b) then
			local bx, by = b.body:getPosition()
			local dx, dy = bx - x, by - y
			local angle = math.atan2(dy, dx)
			local xend = bx + math.cos(angle) * (dx*dx + dy*dy) * 10
			local yend = by + math.sin(angle) * (dx*dx + dy*dy) * 10
			drawDottedLine(bx, by, xend, yend, 4, 5)
		end
    end
	
	--drawDottedLine(10, 10, 300, 300, 4, 5)
end

function love.mousepressed(x, y, button, istouch)
	if button == 1 then
		for i, b in ipairs(objects.balls) do
			if checkCollision(x, y, b) then
				local bx, by = b.body:getPosition()
                local forceX = (bx - x) * 25
                local forceY = (by - y) * 25
                
                b.body:applyLinearImpulse(forceX, forceY)
				
				
			end
		end
	end
end

function checkCollision(mouse_x, mouse_y, ball)
    local bx, by = ball.body:getPosition()
    local distanceSq = (mouse_x - bx)^2 + (mouse_y - by)^2
    
    return distanceSq < ball.radius*ball.radius
end

function drawDottedLine(x1, y1, x2, y2, dotLength, gapLength)
    local dx, dy = x2 - x1, y2 - y1
    local dist = math.sqrt(dx*dx + dy*dy)
    local angle = math.atan2(dy, dx)
    
    local currentDist = 0
    while currentDist < dist do
        -- Calculate the start and end of the dash
        local startX = x1 + math.cos(angle) * currentDist
        local startY = y1 + math.sin(angle) * currentDist
        
        -- Draw a small line segment
        -- If you want actual dots, use love.graphics.points or a very short line
        local endDist = math.min(currentDist + dotLength, dist)
        local endX = x1 + math.cos(angle) * endDist
        local endY = y1 + math.sin(angle) * endDist
        
        love.graphics.line(startX, startY, endX, endY)
        
        -- Move forward by the dot length + the gap
        currentDist = currentDist + dotLength + gapLength
    end
end