local _ENV = mkmodule('flua')

function each(lst, f)
	for index, item in pairs(lst) do
		f(item)
	end
end

function keach(lst, f)
	for key, item in pairs(lst) do
		f(key, item)
	end
end

function ieach(lst, f)
	for i, item in ipairs(lst) do
		f(i,item)
	end
end

function filter(lst, f)
	local results = {}
	each(lst, 
		function(item)
			if f(item) then
				table.insert(results, item)
			end
		end)
	return results
end

function ifilter(lst, f)
	local results = {}
	ieach(lst, 
		function(item)
			if f(i,item) then
				table.insert(results, item)
			end
		end)
	return results
end

function map(lst, f)
	local results = {}
	each(lst, 
		function(item)
			table.insert(results, f(item))
		end)
	return results
end

function imap(lst, f)
	local results = {}
	ieach(lst, 
		function(i,item)
			table.insert(results, f(i,item))
		end)
	return results
end

function fold_left(lst, agg_start, f)
	local result = agg_start
	each(lst,
		function(item)
			result = f(item, result)
		end)
	return result
end

return _ENV;