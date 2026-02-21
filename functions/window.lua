-- on game focus
function love.focus(f)
	if not f then
		print("LOST FOCUS")
	else
		print("GAINED FOCUS")
	end
end

-- on game quit

function love.quit()
	print("Thanks for playing! Come back soon!")
end
