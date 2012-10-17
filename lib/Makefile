all: atscc-jailed

atscc-jailed: atscc-jailed.c
	gcc -m32 -g -o $@ $< -Wl,-static -ljansson -Wl,-Bdynamic -lm
	chmod u+s $@
