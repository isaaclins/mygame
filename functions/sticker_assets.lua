local StickerAssets = {}
local Fonts = require("functions/fonts")

local cache = {}
local FALLBACK_TEMPLATE_PNG = "content/stickers/template.png"
local sticker_abbrev = {
	all_in = "AI",
	bad_luck = "BL?",
	lucky_streak = "LS",
	momentum = "MO",
	risk_reward = "RR",
	jackpot = "JP",
	reverse = "RV",
	odd_todd = "OT",
	even_steven = "ES",
	loaded_dice = "LD",
}

local function shortLabel(sticker)
	if sticker and sticker.id and sticker_abbrev[sticker.id] then
		return sticker_abbrev[sticker.id]
	end
	local id = (sticker and sticker.id) or ""
	if id ~= "" then
		local a, b = id:match("^(%a)[%w_]*_?(%a?)")
		if a and b and b ~= "" then
			return string.upper(a .. b)
		elseif a then
			return string.upper(a)
		end
	end
	return "ST"
end

local function resolveRasterPath(svg_path)
	if not svg_path or svg_path == "" then
		return nil
	end
	if svg_path:sub(-4) == ".svg" then
		return svg_path:sub(1, -5) .. ".png"
	end
	return svg_path
end

function StickerAssets.getImage(svg_path)
	local raster_path = resolveRasterPath(svg_path)
	if not raster_path then
		raster_path = FALLBACK_TEMPLATE_PNG
	end
	if cache[raster_path] ~= nil then
		return cache[raster_path]
	end
	local info = love.filesystem.getInfo(raster_path)
	if not info then
		-- If sticker-specific texture is missing, fallback to template texture.
		if raster_path ~= FALLBACK_TEMPLATE_PNG then
			return StickerAssets.getImage(FALLBACK_TEMPLATE_PNG)
		end
		cache[raster_path] = false
		return nil
	end
	local ok, img = pcall(love.graphics.newImage, raster_path)
	if ok and img then
		img:setFilter("linear", "linear")
		cache[raster_path] = img
	else
		cache[raster_path] = false
	end
	return cache[raster_path] or nil
end

function StickerAssets.drawSticker(sticker, x, y, size, alpha)
	alpha = alpha or 1
	local preferred_raster = resolveRasterPath(sticker.svg_path)
	local using_template = (not preferred_raster) or (love.filesystem.getInfo(preferred_raster) == nil)
	local img = StickerAssets.getImage(sticker.svg_path)
	local ox = (sticker.offset_x or 0) * size
	local oy = (sticker.offset_y or 0) * size
	local angle = math.rad(sticker.angle or 0)
	if img then
		local scale = (sticker.scale or 0.8) * 0.55 * (size / math.max(1, img:getWidth()))
		love.graphics.setColor(1, 1, 1, alpha)
		love.graphics.draw(
			img,
			x + size * 0.5 + ox,
			y + size * 0.5 + oy,
			angle,
			scale,
			scale,
			img:getWidth() * 0.5,
			img:getHeight() * 0.5
		)
		if using_template then
			local prev_font = love.graphics.getFont()
			local tag_h = math.max(8, math.floor(size * 0.12))
			love.graphics.setFont(Fonts.get(tag_h))
			love.graphics.setColor(0.85, 1.0, 1.0, alpha * 0.95)
			love.graphics.printf(
				shortLabel(sticker),
				x + size * 0.5 + ox - size * 0.22,
				y + size * 0.5 + oy - tag_h * 0.5,
				size * 0.44,
				"center"
			)
			love.graphics.setFont(prev_font)
		end
		return true
	end

	-- Last-resort fallback marker when neither sticker png nor template png exists.
	local w = size * 0.36
	local h = size * 0.24
	local cx = x + size * 0.5 + ox
	local cy = y + size * 0.5 + oy
	love.graphics.push()
	love.graphics.translate(cx, cy)
	love.graphics.rotate(angle * 0.55)
	love.graphics.setColor(0.40, 0.95, 1.0, 0.20 * alpha)
	love.graphics.rectangle("fill", -w * 0.5, -h * 0.5, w, h, h * 0.25, h * 0.25)
	love.graphics.setColor(0.75, 1.0, 1.0, 0.70 * alpha)
	love.graphics.setLineWidth(1.5)
	love.graphics.rectangle("line", -w * 0.5, -h * 0.5, w, h, h * 0.25, h * 0.25)
	local prev_font = love.graphics.getFont()
	local font_size = math.max(8, math.floor(h * 0.55))
	love.graphics.setFont(Fonts.get(font_size))
	love.graphics.setColor(0.95, 1.0, 1.0, 0.80 * alpha)
	love.graphics.printf(shortLabel(sticker), -w * 0.5, -h * 0.5 + (h - love.graphics.getFont():getHeight()) * 0.5, w, "center")
	love.graphics.setFont(prev_font)
	love.graphics.pop()
	return true
end

return StickerAssets
