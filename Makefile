# LIB (flex): lfl (gnu/linux, windows); ll (macos)
LIB = ll

CC = gcc
LIBS = -$(LIB) -lm 

all: compile

compile:
	bison -d gram.y
	flex lex.l
	$(CC) gram.tab.c lex.yy.c -o rpg_game $(LIBS)

clean:
	rm -f gram.tab.c gram.tab.h lex.yy.c rpg_game

run:
	@echo "--------- Executing default ---------"
	./rpg_game

run2:
	@echo "------ Executing specific input -----"
	@if [ -z "$(TEST)" ]; then \
		echo "Error: Must specify an argument. Example: make run2 TEST=archivo.txt"; \
	else \
		./rpg_game $(TEST); \
	fi