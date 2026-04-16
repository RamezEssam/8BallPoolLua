local ballShaderCode = [[
    extern vec2 uvOffset;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 p = (texture_coords - vec2(0.5)) * 2.0;
        float len = length(p);
        if (len > 1.0) discard;

        float z = sqrt(1.0 - len * len);
        float u = atan(p.x, z) / 3.14159 + uvOffset.x;
        float v = asin(p.y) / 3.14159 + uvOffset.y;

        float shading = z * 0.7 + 0.3; 
        return Texel(texture, vec2(u, v)) * color * shading;
    }
]]

function love.load()
    -- 1. Screen and Table Setup
    SCREEN_WIDTH = 900
    SCREEN_HEIGHT = 600
    TABLE_WIDTH = 0.6 * SCREEN_WIDTH
    TABLE_HEIGHT = 0.85 * SCREEN_HEIGHT
    BALL_COUNT = 16
    centerX, centerY = SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2

    love.window.setMode(SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.setBackgroundColor(24/255, 24/255, 24/255)

    -- 2. Initialize World and Shader
    world = love.physics.newWorld(0, 0, true)
    ballShader = love.graphics.newShader(ballShaderCode)

    -- 3. Define Official Pool Ball Colors
    local ballColors = {
        [1] = {1, 0.8, 0},     -- Yellow
        [2] = {0, 0, 0.8},     -- Blue
        [3] = {0.8, 0, 0},     -- Red
        [4] = {0.4, 0, 0.6},   -- Purple
        [5] = {1, 0.4, 0},     -- Orange
        [6] = {0, 0.5, 0},     -- Green
        [7] = {0.5, 0, 0},     -- Maroon
        [8] = {0.1, 0.1, 0.1}, -- Black
    }
    -- Balls 9-15 repeat colors 1-7 but will be stripes
    for i = 9, 15 do ballColors[i] = ballColors[i - 8] end

    -- 4. Table Physics Setup
    objects = { table = {}, balls = {} }
    objects.table.body = love.physics.newBody(world, centerX, centerY, "static")
    local wallThickness = 10
    local w, h = TABLE_WIDTH, TABLE_HEIGHT
    local shapes = {
        top    = love.physics.newRectangleShape(0, -h/2, w, wallThickness),
        bottom = love.physics.newRectangleShape(0, h/2, w, wallThickness),
        left   = love.physics.newRectangleShape(-w/2, 0, wallThickness, h),
        right  = love.physics.newRectangleShape(w/2, 0, wallThickness, h)
    }
    for _, shape in pairs(shapes) do
        local fixt = love.physics.newFixture(objects.table.body, shape)
        fixt:setRestitution(1.0)
    end

    -- 5. Ball Initialization Logic
    local margin = wallThickness + 10 
    local minX, maxX = centerX - (w / 2) + margin, centerX + (w / 2) - margin
    local minY, maxY = centerY - (h / 2) + margin, centerY + (h / 2) - margin
    
    -- Generate Numbered Balls (1-15)
	local ballFont = love.graphics.newFont(50)
    for i = 1, BALL_COUNT - 1 do
        local b = {}
        b.radius = 13
		b.number = i
        b.texOffset = {x = math.random(), y = math.random()}
		
        b.texture = generateBallSkin(i, ballColors[i][1], ballColors[i][2], ballColors[i][3], ballFont)
        
        local spawnX, spawnY = math.random(minX, maxX), math.random(minY, maxY)
        b.body = love.physics.newBody(world, spawnX, spawnY, "dynamic")
        b.body:setLinearDamping(0.8) 
        b.shape = love.physics.newCircleShape(b.radius)
        b.fixture = love.physics.newFixture(b.body, b.shape, 1)
        b.fixture:setRestitution(0.9)
        
        table.insert(objects.balls, b)
    end
    
    -- 6. Cue Ball Setup
    local cue = {}
    cue.radius = 13
	cue.number = 0
    cue.texOffset = {x = math.random(), y = math.random()}
    
    -- Generate a plain white skin for the cue ball
    cue.texture = generateBallSkin(nil, 1, 1, 1, ballFont)
    
    local spawnX, spawnY = math.random(minX, maxX), math.random(minY, maxY)
    cue.body = love.physics.newBody(world, spawnX, spawnY, "dynamic")
    cue.body:setLinearDamping(0.8) 
    cue.shape = love.physics.newCircleShape(cue.radius)
    cue.fixture = love.physics.newFixture(cue.body, cue.shape, 1)
    cue.fixture:setRestitution(0.9)
    
    table.insert(objects.balls, cue)
end

function love.update(dt)
    world:update(dt)

    -- 4. UPDATE ROTATION BASED ON PHYSICS VELOCITY
    for _, b in ipairs(objects.balls) do
        local vx, vy = b.body:getLinearVelocity()
        -- Divide by circumference (roughly) to match movement to rotation
        b.texOffset.x = b.texOffset.x + (vx * dt) / (b.radius * 4)
        b.texOffset.y = b.texOffset.y + (vy * dt) / (b.radius * 4)
    end
end

function love.draw()
    -- Draw Table
    love.graphics.setColor(0.15, 0.4, 0.1)
    for _, fixture in ipairs(objects.table.body:getFixtures()) do
        love.graphics.polygon("fill", objects.table.body:getWorldPoints(fixture:getShape():getPoints()))
    end
	
	love.graphics.setColor(1, 1, 1)

    -- 5. DRAW BALLS WITH SHADER
	love.graphics.setShader(ballShader)
	for _, b in ipairs(objects.balls) do
		local bx, by = b.body:getPosition()
		ballShader:send("uvOffset", {b.texOffset.x, b.texOffset.y})
		
		-- Use the specific texture for THIS ball
		love.graphics.draw(b.texture, bx - b.radius, by - b.radius, 0, 
						   (b.radius*2)/b.texture:getWidth(), 
						   (b.radius*2)/b.texture:getHeight())
	end
	love.graphics.setShader()

    -- Draw UI / Dotted Lines
    for _, b in ipairs(objects.balls) do
        local mx, my = love.mouse.getPosition()
        if  b.number == 0 and checkCollision(mx, my, b) then
            local bx, by = b.body:getPosition()
            local dx, dy = bx - mx, by - my
            local angle = math.atan2(dy, dx)
            local xend = bx + math.cos(angle) * (dx*dx + dy*dy) * 15
            local yend = by + math.sin(angle) * (dx*dx + dy*dy) * 15
            love.graphics.setColor(1, 1, 1, 0.5)
            drawDottedLine(bx, by, xend, yend, 4, 5)
        end
    end
end


function love.mousepressed(x, y, button, istouch)
	if button == 1 then
		for i, b in ipairs(objects.balls) do
			if b.number == 0 and checkCollision(x, y, b) then
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
    local distSq = dx*dx + dy*dy
    local angle = math.atan2(dy, dx)
    
    local currentDist = 0
    while currentDist*currentDist < distSq do
        -- Calculate the start and end of the dash
        local startX = x1 + math.cos(angle) * currentDist
        local startY = y1 + math.sin(angle) * currentDist
        
        -- Draw a small line segment
        local endDist = math.min(currentDist + dotLength, distSq)
        local endX = x1 + math.cos(angle) * endDist
        local endY = y1 + math.sin(angle) * endDist
        
        love.graphics.line(startX, startY, endX, endY)
        
        -- Move forward by the dot length + the gap
        currentDist = currentDist + dotLength + gapLength
    end
end


function generateBallSkin(number, color_r, color_g, color_b, ballFont)
    local width, height = 512, 512
    local data = love.image.newImageData(width, height)
    
    -- 1. Check if this is a numbered ball or a cue ball
    local isNumberedBall = type(number) == "number"
    local isStripe = isNumberedBall and (number > 8 and number <= 15)
    
    -- 2. Fill the base color
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            if isStripe then
                if y > height * 0.2 and y < height * 0.8 then
                    data:setPixel(x, y, color_r, color_g, color_b, 1)
                else
                    data:setPixel(x, y, 1, 1, 1, 1) -- White background for stripe
                end
            else
                data:setPixel(x, y, color_r, color_g, color_b, 1) -- Solid color
            end
        end
    end

    -- 3. Draw the Number Circle (Skip if it's the cue ball)
    if isNumberedBall then
        local cx, cy = width / 2, height / 2
        local circle_r = height * 0.2

        for y = math.floor(cy - circle_r), math.floor(cy + circle_r) do
            for x = math.floor(cx - circle_r), math.floor(cx + circle_r) do
                local dx, dy = x - cx, y - cy
                if dx*dx + dy*dy < circle_r*circle_r then
                    data:setPixel(x, y, 1, 1, 1, 1)
                end
            end
        end
    end

    -- 4. Finalize with Canvas to add text
    local skinImage = love.graphics.newImage(data)
    local canvas = love.graphics.newCanvas(width, height)
    
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(skinImage)
    
	-- Only draw text if it's a numbered ball
	if isNumberedBall then
		love.graphics.setColor(0, 0, 0)

		local font = ballFont
		local text = tostring(number)

		local tw = font:getWidth(text)
		local th = font:getHeight()

		local scale = 1.5

		-- center AFTER scaling
		local x = (width / 2) - (tw * scale) / 2
		local y = (height / 2) - (th * scale) / 2

		love.graphics.print(text, x, y, 0, scale, scale)
	end
    
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1)
    
    local finalImage = love.graphics.newImage(canvas:newImageData())
    finalImage:setWrap("repeat", "repeat")
	finalImage:setFilter("nearest", "nearest")
    return finalImage
end