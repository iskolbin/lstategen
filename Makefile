dummy:
	for X in state deserialize serialize; do \
		lua -e "require('parser'); require('test.dummy'); require('$${X}')" > test/$${X}.h; \
	done
	cc test/main.c
