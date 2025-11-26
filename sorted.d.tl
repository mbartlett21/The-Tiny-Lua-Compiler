local record Pairs
   pairs: function<K, V>({K:V}): (function({K:V},K): (K,V), {K:V}, K)

   lessthan: function(any, any): boolean
end

return Pairs
