/* gram.y */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h> 
#include <stdarg.h>
#include <unistd.h>  
#include "rpg.h"    

Character player1;
Character player2;
int char_count = 0;
int fool_count = 0;

int role_cnt = 0;
int hp_cnt = 0;
int dmg_cnt = 0;
int spd_cnt = 0;

extern FILE *yyin;
void yyerror(const char *s);
int yylex();

const char* VALID_ROLES[] = { "mage", "knight", "thief" };
Character* current_char();

void slow_print(const char *format, ...);
int play_escape_roulette(int success_chance);
void handle_flee(char* name);
int roll_dice();

%}

%union {
    int intValue;
    char* strValue;
}

%token <intValue> T_NUM
%token <strValue> T_ID T_STRING
%token T_CHARACTER T_ROLE T_HP T_DAMAGE T_SPEED
%token LBRACE RBRACE EQUALS SEMICOLON

%token T_ATTACKS T_DEFENDS T_FLEES USES T_ABILITY T_STATUS T_HELP T_QUIT ON CHECKS

%%

/* --- GRAMMAR --- */

all: document 
   | command 
   ;

/* -------- PHASE 1 -------- */

document: character character ; 

character: T_ID LBRACE attribute_list RBRACE
    {
        Character* current = current_char();
        current->name = $1; 

        if (role_cnt > 1 || hp_cnt > 1 || dmg_cnt > 1 || spd_cnt > 1) {
            printf("\n>> [ERROR] Invalid declaration: Duplicate attributes found for %s.\n", $1);
            YYABORT; 
        }

        if (current->role == NULL) current->role = strdup("invalid");

        int is_mage   = (strcmp(current->role, "mage") == 0);
        int is_knight = (strcmp(current->role, "knight") == 0);
        int is_thief  = (strcmp(current->role, "thief") == 0);

        if (!is_mage && !is_knight && !is_thief) {
            fool_count++; 
            
            if (fool_count == 1) {
                slow_print("\n>> [SYSTEM-WARNING] Your character does not have a valid role"
                    "\n>> [SYSTEM] You are in need of a role, player these may aid you on the field"
                    ">> \n[NARRATOR] You will be assigned a random role since you clearly cannot follow basic instructions.", current->role);
            } else { 
                slow_print("\n>> [NARRATOR] Another indecisive fool... A random role it is.");
            }
            
            int random_idx = rand() % 3; 
            current->role = strdup(VALID_ROLES[random_idx]);
        }

        if (strcmp(current->role, "mage") == 0)        current->ability = strdup("Fireball");
        else if (strcmp(current->role, "knight") == 0) current->ability = strdup("Slash");
        else if (strcmp(current->role, "thief") == 0)  current->ability = strdup("Steal");

        /* Randomization Logic */
        if(current->hp == -1){
            slow_print("\n>> [SYSTEM-WARNING] Your character does not have any HP"
                    "\n>> [SYSTEM] Player! You need HP to make the battle interesting... I mean *cof*... To survive!"
                    "\n>> [NARRATOR] Oh! Interesting choice, your character has no HP! You foolish player..."
                    "\n>> [NARRATOR] Clearly you will be assigned a random value due to your lack of knowledge on duels...");            
            current->hp = (rand() % 500) + 50; 
        } 
        
        if(current->damage == -1){
            slow_print("\n>> [SYSTEM-WARNING] Your character does not have any damage stats"
                    "\n>> [SYSTEM] Damage is key for a dule, player!"
                    "\n>> [NARRATOR] Splendid choice of battle! You choose to be a hippie, how charming..."
                    "\n>> [NARRATOR] Tragically, your wish will not be granted, random value it is!");
            current->damage = (rand() % 50) + 10;
        }

        if(current->speed == -1){
            slow_print("\n>> [SYSTEM-WARNING] Your character does not have any damage stats"
                    "\n>> [SYSTEM] Speed is important, player!"
                    "\n>> [NARRATOR] Even though I wish I could grant you your wish of being a snail... "
                    "\n>> [NARRATOR] ...Random value it is!" );
            current->speed = (rand() % 20) + 1;
        }
        
        slow_print("\n\n>> [SYSTEM] Character Ready: %s (Class: %s) | HP: %d | DMG: %d\n", 
            current->name, current->role, current->hp, current->damage);
        /*printf("\n--- Next character ---\n");*/
        
        /* Reset counters for next character */
        role_cnt = 0; hp_cnt = 0; dmg_cnt = 0; spd_cnt = 0;
        
        char_count++;
    }
;

attribute_list: attribute_list attribute
              | attribute
              ;

attribute: role_attr
         | hp_attr
         | damage_attr
         | speed_attr
         ;

role_attr:  T_ROLE EQUALS T_STRING SEMICOLON
                { 
                    slow_print("\n>> [SYSTEM] Loading role...");
                    current_char()->role = strdup($3); role_cnt++; 
                } 
            | T_ROLE EQUALS SEMICOLON
                { current_char()->role = NULL; role_cnt++; }
         ;
         
hp_attr: T_HP EQUALS T_NUM SEMICOLON
            { 
                slow_print("\n>> [SYSTEM] Loading HP stats...");
                current_char()->hp = $3; hp_cnt++; 
            }
        | T_HP EQUALS SEMICOLON
            { current_char()->hp = -1; hp_cnt++; }
        ;

damage_attr: T_DAMAGE EQUALS T_NUM SEMICOLON
                { 
                    slow_print("\n>> [SYSTEM] Loading damage data...");
                    current_char()->damage = $3; dmg_cnt++; 
                }
            | T_DAMAGE EQUALS SEMICOLON
                { current_char()->damage = -1; dmg_cnt++; }
           ;

speed_attr: T_SPEED EQUALS T_NUM SEMICOLON
                { 
                    slow_print("\n>> [SYSTEM] Loading speed stats...");
                    current_char()->speed = $3; spd_cnt++; 
                }
          | T_SPEED EQUALS SEMICOLON
                { current_char()->speed = -1; spd_cnt++; }
          ;

/* ------------------------ */

/* -------- PHASE 2 -------- */

command: action SEMICOLON ;

action: targeted
      | self
      | global
      ;

/* 1. Actions that require 2 names (Attacker -> Victim) */
targeted: 
    T_ID T_ATTACKS T_ID 
        { 
            //implement
        }
    T_ID USES T_ABILITY ON T_ID
        { 
            //implement
        }
    ;

/* 2. Actions that require 1 name (Actor does something) */
self:
    | T_ID T_DEFENDS
        {
            //implement
        }
    | T_ID T_FLEES
        {
            //implement
        }
    | T_ID CHECKS T_STATUS
        {
            //implement
        }
    ;

global:
    T_HELP
    {
        slow_print("\n====================== RULES ======================"
                   "\nThe character with more speed begins the first attack"
                   "\nEvery character may use one action per round"
                   "\n\nEvery player can use the following commands:"
                   "\n\t -> ATTACK: "
                   "\n\t\t - Syntax: character1 attacks character2"
                   "\n\t\t - This lowers the enemie's HP."
                   "\n\t -> ABILITY: "
                   "\n\t\t - Syntax: character1 uses ability on character2"
                   "\n\t\t - The ability is based on the role:"
                   "\n\t\t\t * Mague: uses magic -> deals 150%% of their base damage."
                   "\n\t\t\t\t ** This ability has a cooldown of 2 turns."
                   "\n\t\t\t * Knight: uses slash -> deals 200%% of their base damage."
                   "\n\t\t\t\t ** This ability has a cooldown of 3 turns."
                   "\n\t\t\t * Thief: uses steal -> steals the weapon of its enemmie, using its ability against them."
                   "\n\t\t\t\t ** This ability may be only used ONCE, think it through."
                  );
    slow_print("\n\t -> DEFENSE: "
                   "\n\t\t - Syntax: character1 defends"
                   "\n\t\t - This makes next attack the character receives be 50%% of the actual damage."
                   "\n\t\t - BONUS: a dice will be roled, if the numer is 4 or over, the round after it is also reduced 25%%!"
                   "\n\t -> FLEES: "
                   "\n\t\t - Syntax: character1 flees"
                   "\n\t\t - This enters full gambling mode, here the speed is very important! A roulette will be turn to decide your fate."
                   "\n\t -> STATUS: "
                   "\n\t\t - Syntax: character1 checks status"
                   "\n\t\t - This will print the character's status and all of their stats."
                   "\n\t -> QUIT: "
                   "\n\t\t - Syntax: quit"
                   "\n\t\t - This options is used to quit the battle, but do not worry, only rats use this."
                   "\n\n Use the command help anytime if you want a refresh on the rules"
                   "\n==================================================");
    }
    | T_QUIT
    {
        slow_print("\n>> [NARRATOR] You coward! You shall never come ba...*glitches*"
                   "\n>> ... [SYSTEM] The simulation ends.\n");
        exit(0);
    }
    ;

/* ------------------------ */

%%

/* --- C CODE SECTION --- */
Character* current_char() {
    return (char_count == 0) ? &player1 : &player2;
}

int main(int argc, char **argv) {
    srand(time(NULL)); 

    // inicialization of variables
    player1.hp = -1; player1.damage = -1; player1.speed = -1; player1.role = NULL;
    player2.hp = -1; player2.damage = -1; player2.speed = -1; player2.role = NULL;

    // input file
    FILE *file = fopen("input.txt", "r"); 
    if (!file) { perror("Error opening file"); return 1; }
    yyin = file; 
    
    //first text
    printf("==================== WELCOME =================");
    slow_print("\nWelcome to the rift fighters!"
            "\nThis adventure is dividied in two fases:"
            "\n\t 1. The system will register your characters."
            "\n\t 2. They will fight to DEATH!!!"
            "\nWe shall see who is the toughest one of all."
            "\nDuring the combact, if you are in need of aid just type 'help' to discover what your options are."
            "\nMay the odds be ever in your favor.");
    printf("\n============================================\n");

    // beginning of phase1
    slow_print("\n--- PHASE 1: Loading Characters ---\n");
    yyparse(); 
    slow_print("\nCharacters loaded successfully.\n");
    slow_print("\n--- PHASE 1 COMPLETE ---\n");


    slow_print("\n--- PHASE 2: Combact ---\n");
    slow_print("\n>> [SYSTEM] Let's go over the rules!"
               "\n>> [NARRATOR] ZZZzzz "
               "\n>> [SYSTEM] Oh :("
               "\n>> [SYSTEM] Player, you want to hear the rules, right?...\n");

    /* IT DOES NOT PRINT EVERYTHING CORRECTLY -> DO IT IN SEPARATE SLOW_PRINTS */
    slow_print("\n====================== RULES ======================"
                   "\nThe character with more speed begins the first attack"
                   "\nEvery character may use one action per round"
                   "\n\nEvery player can use the following commands:"
                   "\n\t -> ATTACK: "
                   "\n\t\t - Syntax: character1 attacks character2"
                   "\n\t\t - This lowers the enemie's HP."
                   "\n\t -> ABILITY: "
                   "\n\t\t - Syntax: character1 uses ability on character2"
                   "\n\t\t - The ability is based on the role:"
                   "\n\t\t\t * Mague: uses magic -> deals 150%% of their base damage."
                   "\n\t\t\t\t ** This ability has a cooldown of 2 turns."
                   "\n\t\t\t * Knight: uses slash -> deals 200%% of their base damage."
                   "\n\t\t\t\t ** This ability has a cooldown of 3 turns."
                   "\n\t\t\t * Thief: uses steal -> steals the weapon of its enemmie, using its ability against them."
                   "\n\t\t\t\t ** This ability may be only used ONCE, think it through."
                  );
    slow_print("\n\t -> DEFENSE: "
                   "\n\t\t - Syntax: character1 defends"
                   "\n\t\t - This makes next attack the character receives be 50%% of the actual damage."
                   "\n\t\t - BONUS: a dice will be roled, if the numer is 4 or over, the round after it is also reduced 25%%!"
                   "\n\t -> FLEES: "
                   "\n\t\t - Syntax: character1 flees"
                   "\n\t\t - This enters full gambling mode, here the speed is very important! A roulette will be turn to decide your fate."
                   "\n\t -> STATUS: "
                   "\n\t\t - Syntax: character1 checks status"
                   "\n\t\t - This will print the character's status and all of their stats."
                   "\n\t -> QUIT: "
                   "\n\t\t - Syntax: quit"
                   "\n\t\t - This options is used to quit the battle, but do not worry, only rats use this."
                   "\n\n Use the command help anytime if you want a refresh on the rules"
                   "\n==================================================");

    /* Commented out Phase 2 loop for testing */
    /*
    yyin = stdin;
    yyrestart(yyin);
    while(1) { ... } 
    */

    slow_print("\n--- PHASE 2: Combact ---\n");
    
    return 0;
}

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}

void slow_print(const char *format, ...) {
    va_list args;
    char buffer[1024]; 
    
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    
    int i = 0;
    while (buffer[i] != '\0') {
        printf("%c", buffer[i]);
        fflush(stdout); 
        usleep(45000); 
        i++;
    }
}

/* RULETA -> code found online lol */
int play_escape_roulette(int success_chance) {
    const char spin_chars[] = {'|', '/', '-', '\\'}; 
    int final_roll = rand() % 100; 
    int is_success = (final_roll < success_chance);
    
    int loops = 25; 
    int delay = 30000; 

    printf("\n"); 

    for (int i = 0; i < loops; i++) {
        int visual_number = rand() % 100; 
        char spinner = spin_chars[i % 4];

        printf("\r>> [ESCAPING] Speed Check: [%c] %3d%% required vs %3d%% rolled...", 
               spinner, success_chance, visual_number);
        
        fflush(stdout); 
        usleep(delay);
        delay += (i * 2000); 
    }

    if (is_success) {
        printf("\r>> [ESCAPING] Speed Check: [OK] %3d%% required vs %3d%% rolled... SUCCESS!\n", 
               success_chance, final_roll);
    } else {
        printf("\r>> [ESCAPING] Speed Check: [XX] %3d%% required vs %3d%% rolled... FAILED! \n", 
               success_chance, final_roll);
    }
    
    // Pausa dramática final
    usleep(500000); 
    
    return is_success;
}

/*
void handle_flee(char* name) {
    Character* c = get_char(name);
    
    int chance = c->speed * 5; 
    if (chance > 90) chance = 90; 
    if (chance < 10) chance = 10;

    slow_print("\n>> [ACTION] %s attempts to flee from battle!", c->name);
    slow_print("\n>> [NARRATOR] Can those cowardly legs run fast enough?\n");

    // LLAMADA A LA RULETA
    int escaped = play_escape_roulette(chance);

    if (escaped) {
        slow_print("\n>> [NARRATOR] Look at them go! Like a dust cloud in the wind.\n");
        slow_print(">> [RESULT] %s escaped successfully. Battle ends.\n", c->name);
        exit(0);
    } else {
        slow_print("\n>> [NARRATOR] Tripped over their own shoelaces. Pathetic.\n");
        slow_print(">> [RESULT] Escape failed! The battle continues.\n");
        
        // Opcional: Penalización por fallar
        // c->hp -= 10;
        // printf(">> [PENALTY] Took 10 damage while tripping.\n");
    }
}
    */

/* DADO -> tamvién internet lol */
int roll_dice() {
    int final_val = (rand() % 6) + 1; 
    int loops = 20;                   
    int delay = 20000;               

    printf("\n");

    for (int i = 0; i < loops; i++) {
        int visual_val = (rand() % 6) + 1;
        
        printf("\r>> [DICE] Rolling... [ %d ]", visual_val);
        
        fflush(stdout); 
        usleep(delay);
        
        if (i > 15) delay += 40000; 
        else delay += 2000;
    }

    printf("\r>> [DICE] Rolling... [ %d ] -> RESULT!\n", final_val);
    
    usleep(300000); 
    
    return final_val;

    /* MODO DE IMPRESIÓN PRO
    char* faces[] = {"?", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"}; 

    for (int i = 0; i < loops; i++) {
        int v = (rand() % 6) + 1;
        printf("\r>> [DICE] Rolling... %s ", faces[v]); 
        fflush(stdout);
        usleep(delay);
        // ... aumento de delay ...
    }
    printf("\r>> [DICE] Rolling... %s  (%d)!\n", faces[final_val], final_val);*/
}