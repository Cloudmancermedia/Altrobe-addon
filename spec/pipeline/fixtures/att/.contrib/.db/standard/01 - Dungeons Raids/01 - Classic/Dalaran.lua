-- Hand-written fixture in the shape of upstream's Classic source files. Only the comments are read.
inst(2959, {	-- City of Dalaran
	["groups"] = {
		n(4887, {	-- Ghamoo-Ra
		}),
		e(3313, {	-- Standard Only Boss
		}),
		q(1, {
			["cr"] = 5003,	-- Wing Boss
		}),
		n_conditional(5006, {	-- Conditional Mob
		}),
		q(2, {
			["provider"] = { "n", 5005 },	-- Provider Mob
		}),
	},
});
