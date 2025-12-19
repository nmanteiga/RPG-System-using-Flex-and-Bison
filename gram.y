/* gram.y */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h> 
#include <stdarg.h>
#include <unistd.h>  
#include <termios.h>
#include <fcntl.h>
#include "rpg.h"    

Character player1;
Character player2;
Character* current;
int char_count = 0;
int fool_count = 0;
int silent_mode = 0;

int role_cnt = 0;
int hp_cnt = 0;
int dmg_cnt = 0;
int spd_cnt = 0;

extern FILE *yyin;
void yyerror(const char *s);
int yylex();
void yyrestart(FILE *input_file);

const char* VALID_ROLES[] = { "mage", "knight", "thief" };
Character* current_char();

Character* get_char(char* name);
Character* get_opponent(char* name);
void slow_print(const char *format, ...);
int ride_roulette(int success_chance);
int roll_dice();
void free_characters();


%}

%union {
    int intValue;
    char* strValue;
}

%token <intValue> T_NUM
%token <strValue> T_ID T_STRING
%token T_ROLE T_HP T_DAMAGE T_SPEED
%token LBRACE RBRACE EQUALS SEMICOLON

%token T_ATTACKS T_DEFENDS T_FLEES USES T_ABILITY T_STATUS T_HELP T_QUIT ON CHECKS

%%

/* --- GRAMMAR --- */

all: document 
   | command 
   ;

/* -------- PHASE 1 -------- */

document: character character { YYACCEPT; } ;

character: T_ID LBRACE attribute_list RBRACE
    {
        Character* current = current_char();
        current->name = $1; 

        /* --- */
        /* duplicate atributes */

        if (role_cnt > 1 || hp_cnt > 1 || dmg_cnt > 1 || spd_cnt > 1) {
            printf("\n>> [ERROR] Invalid declaration: Duplicate attributes found for %s.\n", $1);
            printf("\n============================================\n");
            free_characters();
            exit(0); 
        }

        /* --- */

        /* random role if role is NULL */
        if (current->role == NULL) current->role = strdup("invalid");

        int is_mage   = (strcmp(current->role, "mage") == 0);
        int is_knight = (strcmp(current->role, "knight") == 0);
        int is_thief  = (strcmp(current->role, "thief") == 0);

        /* dialogue for random role */
        if (!is_mage && !is_knight && !is_thief) {
            fool_count++; 
            
            if (fool_count == 1) {
                slow_print("\n>> [SYSTEM-WARNING] Your character does not have a valid role"
                    "\n>> [NARRATOR] You will be assigned a random role since you clearly cannot follow basic instructions.", current->role);
            } else { 
                slow_print("\n>> [NARRATOR] Another indecisive fool... A random role it is.");
            }
            
            int random_idx = rand() % 3; 
            current->role = strdup(VALID_ROLES[random_idx]);
        }

        /* random hp + dialogue */
        if(current->hp == -1){
            slow_print("\n>> [SYSTEM-WARNING] Your character does not have any HP"
                    "\n>> [SYSTEM] Player! You need HP to make the battle interesting... I mean *cof*... To survive!"
                    "\n>> [NARRATOR] Clearly you will be assigned a random value due to your lack of knowledge on duels...");            
            current->hp = (rand() % 1000) + 50; 
        } 
    
        /* random damage + dialogue */
        if(current->damage == -1){
            slow_print("\n>> [SYSTEM-WARNING] Your character does not have any damage stats"
                    "\n>> [NARRATOR] Splendid choice of battle! You choose to be a hippie, how charming..."
                    "\n>> [NARRATOR] Tragically, your wish will not be granted, random value it is!");
            current->damage = (rand() % 200) + 10;
        }

        /* random speed + dialogue */
        if(current->speed == -1){
            slow_print("\n>> [SYSTEM-WARNING] Your character does not have any speed stats"
                    "\n>> [SYSTEM] Speed is important, player!"
                    "\n>> [NARRATOR] Even though I wish I could grant you your wish of being a snail... "
                    "\n>> [NARRATOR] ... you shall get a random value!" );
            current->speed = (rand() % 20) + 1;
        }
        
        slow_print("\n\n>> [SYSTEM] Character Ready: %s | Role: %s | HP: %d | DMG: %d | Speed: %d |\n", 
            current->name, current->role, current->hp, current->damage, current->speed);
        
        /* variable reset for next character */
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

/* assignment of values for the attributes */
role_attr:  T_ROLE EQUALS T_STRING SEMICOLON
                {  
                    slow_print("\n>> [SYSTEM] Loading role...");
                    current_char()->role = strdup($3); role_cnt++; 
                } 
         ;
         
hp_attr: T_HP EQUALS T_NUM SEMICOLON
            { 
                slow_print("\n>> [SYSTEM] Loading HP stats...");
                current_char()->hp = $3; hp_cnt++; 
            }
        ;

damage_attr: T_DAMAGE EQUALS T_NUM SEMICOLON
                { 
                    slow_print("\n>> [SYSTEM] Loading damage data...");
                    current_char()->damage = $3; dmg_cnt++; 
                }
           ;

speed_attr: T_SPEED EQUALS T_NUM SEMICOLON
                { 
                    slow_print("\n>> [SYSTEM] Loading speed stats...");
                    current_char()->speed = $3; spd_cnt++; 
                }
          ;

/* ------------------------ */
/* -------- PHASE 2 -------- */

command: action { YYACCEPT; } ;

action: targeted
      | self
      | global
      ;

/* 1. actions that require 2 names (attacker -> victim) */
targeted: 
    T_ID T_ATTACKS T_ID SEMICOLON
    { 
        if (strcmp($1, current->name) != 0) /* error handling */
            slow_print("\n>> [SYSTEM-ERROR] It is not %s's turn! Wait for %s to finish.\n", $1, current->name);

        else {
            Character* opponent = get_char($3);

            /* --- */
            /* error handling */

            if (opponent == NULL) 
                slow_print("\n>> [SYSTEM-ERROR] You are attacking a ghost? %s does not exist.", $3);

            else if (opponent == current) {
                slow_print("\n>> [NARRATOR] I see how it is, if you want to kill yourself just say so");
                slow_print("\n>> [SYSTEM] Wait! %s made a mistake!", current->name);
                slow_print("\n>> [NARRATOR] If the dice gets fewer than a 5 you shall face your faith");
                int roll = roll_dice(); 

                if (roll >= 5) {
                    current->hp = 0; 
                    slow_print("\n>> [SUCCESS] ✔ Your survived!");

                } else {
                    slow_print("\n>> [FAILURE] ✘ Oh, bye player");
                    printf("\n============================================\n");
                    free_characters();
                    exit(0);
                }
                
            /* --- */  

            } else {
                int damage = current->damage;

                slow_print("\n>> [SYSTEM] %s uses ATTACK on %s", current->name, opponent->name);

                /* lower damage if user is defending */
                if (opponent->defending == 1) {
                    damage = damage * 0.5;
                    slow_print("\n>> [NARRATOR] Defense is key! This attack only deals 50%% (%d, in case you are not good at math ;)", damage); 

                } else if (opponent->defending == 2) {
                    damage = damage * 0.25;
                    slow_print("\n>> [NARRATOR] Someone got lucky on the dice... Sorry for you %s you damage is reduced by 25%%", current->name);
                    slow_print("\n>> [NARRATOR] In case you have not taken a math 101 yet, it is %d", damage);
                }

                /* deals the damage */
                opponent->hp -= damage;
                if (opponent->hp < 0) opponent->hp = 0; 
                current->defending = 0; 

                slow_print("\n>> [SYSTEM] %s dealt %d damage to %s", current->name, damage, opponent->name);
                slow_print("\n>> [SYSTEM] %s has %d HP left", opponent->name, opponent->hp);

                if (opponent->hp == 0) { /* if the any of the players dies */
                    slow_print("\n\n>> [VICTORY] %s has been defeated! %s wins!\n", opponent->name, current->name);
                    slow_print("\n>> [NARRATOR] Pitty... I was rooting for the other one..");
                    slow_print("\n>> [SYSTEM] You owe me 5 golden coins :3");
                    slow_print("\n>> [%s] ...", current->name);
                    slow_print("\n>> [NARRATOR] Whatever... *hangs coins to SYSTEM*");
                    slow_print("\n>> [SYSTEM] :D"
                               "\n>> [SYSTEM] See you soon player!"
                               "\n>> [NARRATOR] Or not...");
                    printf("\n============================================\n");
                    free_characters();
                    exit(0);

                } else { /* gives turn to opponent */
                     current = opponent; 
                     printf("\n\n--------------------------------------------------");
                     slow_print("\n>> [SYSTEM] It is now %s's turn", current->name);

                    if(current->cooldown > 0) current->cooldown -= 1;
                    if(current->cooldown == 0) slow_print("\n>> [SYSTEM] %s, your ability is ready!", current->name);
                }
            }
        }
    }
    | T_ID USES T_ABILITY ON T_ID SEMICOLON
        { 
            if (strcmp($1, current->name) != 0) /* error handling */
                slow_print("\n>> [SYTEM-ERROR] It is not %s's turn! Wait for %s to finish.\n", $1, current->name);
            else {
                Character* opponent = get_char($5);
                char* role = current->role;
                int cooldown = current->cooldown;
                int damage = current->damage;
                int continues = 0;

                /* --- */
                /* error handling */

                if (opponent == NULL) 
                    slow_print("\n>> [SYSTEM-ERROR] You are attacking a ghost? %s does not exist.", $5);

                else if (opponent == current) {
                    slow_print("\n>> [NARRATOR] I see how it is, if you want to kill yourself just say so");
                    slow_print("\n>> [SYSTEM] Wait! %s made a mistake!", current->name);
                    slow_print("\n>> [NARRATOR] If the dice gets fewer than a 5 you shall face your faith");
                    int roll = roll_dice(); 

                    if (roll >= 5) {
                        current->hp = 0; 
                        slow_print("\n>> [SUCCESS] ✔ Your survived!");

                    } else {
                        slow_print("\n>> [FAILURE] ✘ Oh, bye player");
                        printf("\n============================================\n");
                        free_characters();
                        exit(0);
                    }
                }

                /* --- */

                /* ability for magues */
                if(strcmp(role, "mage")==0 && cooldown == 0){
                    slow_print("\n>> [SYSTEM] %s uses MAGIC on %s", current->name, opponent->name);
                    damage = damage * 1.5;
                        
                    /* lower damage if opponent is defending */    
                    if (opponent->defending == 1) {
                        damage = damage * 0.5;
                        slow_print("\n>> [NARRATOR] Defending, I see! This attack only deals 50%% (It is %d, you fool..)", damage);  

                    } else if (opponent->defending == 2) {
                        damage = damage * 0.25;
                        slow_print("\n>> [NARRATOR] Lucky bastards... Pitty for you %s you damage is reduced by 25%%", current->name);
                        slow_print("\n>> [NARRATOR] In case you are poor, it is %d", damage);
                    }
                    current->cooldown = 4;

                /* ability for knights */
                } else if(strcmp(role, "knight")==0 && cooldown == 0){
                    slow_print("\n>> [SYSTEM] %s uses SLASH on %s", current->name, opponent->name);
                    damage = damage * 2;
                        
                    /* lower damage if opponent is defending */
                    if (opponent->defending == 1) {
                        damage = damage * 0.5;
                        slow_print("\n>> [NARRATOR] Shielding up, nice move I guess... This attack only deals 50%% (For the uneducated bastards out there -> %d)", damage);  

                    } else if (opponent->defending == 2) {
                        damage = damage * 0.25;
                        slow_print("\n>> [NARRATOR] Lucky lucky you, %s... Unlucky you %s you damage is reduced by 25%%", opponent->name, current->name);
                        slow_print("\n>> [NARRATOR] Come on, it is not hard to calculate" 
                                   "\n>> [NARRATOR] WOW, ok, it is %d (wow.)", damage);
                    }
                    current->cooldown = 6;

                /* ability for thiefs */
                } else if (strcmp(role, "thief")==0 && cooldown == 0){
                    slow_print("\n>> [SYSTEM] %s STEALS from %s", current->name, opponent->name);
                    
                    char* weapon = NULL;
                    if(strcmp(opponent->role, "mage")==0) weapon = "magic wand";
                    else if(strcmp(opponent->role, "knight")==0) weapon = "the king's sword";

                    /* ability for opponents that are NOT thiefs */
                    if(weapon != NULL){
                        slow_print("\n>> [NARRATOR] %s uses their magical stealing abilities and steals %s's %s", current->name, opponent->name, weapon);

                        /* thief vs mague */
                        if(strcmp(opponent->role, "mage")==0){ 
                            slow_print("\n>> [NARRATOR] Wow, %s Master of Thiefs, just learned how to do magic"
                                       "\n>> [NARRATOR] This will be interesting nontheless...");

                            /* in case the thief's base damage is greater than the opponenet's */
                            if(current->damage > opponent->damage){
                                slow_print("\n>> [NARRATOR] Ups! Seems like someone, not pointing any fingers (%s), is quite weak...", opponent->name);
                                slow_print("\n>> [NARRATOR] I guess %s will have to use their base damage", current->name);

                                damage = damage * 1.5;
                            } else 
                                damage = opponent -> damage * 1.5;

                            /* thief's ability caannot be defended */
                            if(opponent->defending != 0)
                            slow_print("\n>> [NARRATOR] Sorry pal (not really), defense is not useful against this attack...sucks to be you");
                    
                            
                        /* thief vs knight */
                        } else {
                            slow_print("\n>> [NARRATOR] How did %s suddenly grow muscles?", current->name);
                            slow_print("\n>> [NARRATOR] Well I guess the gym routine of a thief is a thief's secret"
                                       "\n>> [NARRATOR] %s manages to hold %s's %s", current->name, opponent->name, weapon);

                            /* in case the thief's base damage is greater than the opponenet's */
                            if(current->damage > opponent->damage){
                                    slow_print("\n>> [NARRATOR] Ups! Seems like someone, not pointing any fingers (%s), is quite weak...", opponent->name);
                                    slow_print("\n>> [NARRATOR] I guess %s will have to use their base damage", current->name);
                                    slow_print("\n>> [NARRATOR] Seriously, what kind of knight are you %s?", opponent->name);

                                    damage = damage * 2;
                            } else 
                                damage = opponent->damage * 2;

                            /* thief's ability caannot be defended */
                            if(opponent->defending != 0)
                            slow_print("\n>> [NARRATOR] Sorry pal (not really), defense is not useful against this attack...sucks to be you");
                    
                        }

                    /* thief vs thief */
                    } else {
                        slow_print("\n>> [NARRATOR] This is a tricky battle, a thief cannot steal from another thief"
                                   "\n>> [NARRATOR] That is basic thief code"
                                   "\n>> [SYSTEM] It is? I though thiefs did not have codes"
                                   "\n>> [NARRATOR] ... System, I beg of you, do not embarasse me like that again...");
                        damage = damage * 2;
                        slow_print("\n>> [NARRATOR] Anyhow, everyone knows there are no codes for back-stabbing, hihi");
                        slow_print("\n>> [SYSTEM] Wow, %s back-stabs %s", current->name, opponent->name);

                        /* thief's ability caannot be defended */
                        if(opponent->defending != 0)
                            slow_print("\n>> [NARRATOR] Sorry pal (not really), defense is not useful against this attack...sucks to be you");
                    } 
                    current->cooldown = -1;

                } else { /* error handling */
                    continues = 1;
                    slow_print("[SYSTEM-ERROR] You are under cooldown, you cannot use your ability");
                }

                if(continues == 0){
                    /* deals the damage */
                    opponent->hp -= damage;
                    if (opponent->hp < 0) opponent->hp = 0; 
                    current->defending = 0; 

                    if (opponent->hp < 0) opponent->hp = 0; 

                    slow_print("\n>> [SYSTEM] %s dealt %d damage to %s", current->name, damage, opponent->name);
                    slow_print("\n>> [SYSTEM] %s has %d HP left", opponent->name, opponent->hp);

                    /* in case the opponent dies */
                    if (opponent->hp == 0) {
                        slow_print("\n\n>> [VICTORY] %s has been defeated! %s gets to life another day!\n", opponent->name, current->name);
                        slow_print("\n>> [NARRATOR] Hehe... I was rooting for this one");
                        slow_print("\n>> [%s] 0//o//0", current->name);
                        slow_print("\n>> [NARRATOR] Oh, get over it! System, do not leave! YOU OWE ME 5 GOLDEN COINS");
                        slow_print("\n>> (System had a bit too much fun on the roulette...)" 
                                "\n>> [SYSTEM] See you soon, player! *runs away*"
                                "\n>> [NARRATOR] You will not be hearing from him soon *runs after him*..."
                                "\n>> [SCAREDD-SYSTEM] DDD:");
                        printf("\n============================================\n");
                        free_characters();
                        exit(0);

                    } else { /* gives turn to opponent */
                        current = opponent; 
                        printf("\n\n--------------------------------------------------");
                        slow_print("\n>> [SYSTEM] It is now %s's turn", current->name);
                    }
                }
            }
        }
    ;

/* 2. actions that require 1 name */
self:
    T_ID T_DEFENDS SEMICOLON
        {
            if (strcmp($1, current->name) != 0) /* error handling */
                slow_print("\n>> [SYTEM-ERROR] It is not %s's turn! Wait for %s to finish.\n", $1, current->name);
            else {
                Character* opponent = get_opponent($1);

                slow_print("\n>> [SYSTEM] %s takes a defensive stance...", current->name);
                slow_print("\n>> [SYSTEM] Rolling for Bonus Defense (needs 4+)...");
                int roll = roll_dice(); 

                /* rolls dice */
                if (roll >= 4) { 
                    current->defending = 2; 
                    slow_print("\n>> [SUCCESS] ✔ Critical Block! Damage will be reduced by 75%% next turn!");
                } else {
                    current->defending = 1; 
                    slow_print("\n>> [DEFENSE] Standard guard up. Damage reduced by 50%%.");
                }
                
                if(current->cooldown > 0) current->cooldown -= 1;
                if(current->cooldown == 0) slow_print("\n>> [SYSTEM] %s, your ability is ready!", current->name);

                /* gives turn to opponent */
                current = opponent; 
                printf("\n\n--------------------------------------------------");
                slow_print("\n>> [SYSTEM] It is now %s's turn", current->name);
            }
        }
    | T_ID T_FLEES SEMICOLON
        {    
            if (strcmp($1, current->name) != 0)  /* error handling */
                slow_print("\n>> [SYSTEM-ERROR] It is not %s's turn! Wait for %s to finish.\n", $1, current->name);
            else {
                slow_print("\n>> [SYSTEM] %s looks around nervously, looking for an exit...", current->name);
                
                /* success rate */
                int chance = current->speed * 4;
                if (chance > 90) chance = 90; 
                if (chance < 10) chance = 10;

                slow_print("\n>> [NARRATOR] Oh look! %s is trying to run away like a chicken!", current->name);
                int escaped = ride_roulette(chance); /* roulette rides */

                /* if the character scaped */
                if (escaped) {
                    slow_print("\n>> [NARRATOR] Unbelievable... They actually ran away.");
                    slow_print("\n>> [SYSTEM] Creating 'Coward' achievement for %s...", current->name);
                    slow_print("\n>> [SYSTEM] Battle ended due to abandonment.");
                    printf("\n============================================\n");
                    free_characters();
                    exit(0); 

                /* if they did not */
                } else {
                    slow_print("\n>> [NARRATOR] HAHAHA! Tripped over their own shoelaces!");
                    slow_print("\n>> [SYSTEM] Escape failed. You lose your turn.");
                    slow_print("\n>> [NARRATOR] That is what you get for being a chicken, you may never go back to your coop!");
                    
                    Character* opponent = get_opponent($1);
                    current = opponent; 

                    /* gives turn to opponent */
                    printf("\n\n--------------------------------------------------");
                    printf("\n>> [SYSTEM] It is now %s's turn", current->name);

                    if (current->cooldown > 0) current->cooldown -= 1;
                    if (current->cooldown == 0) slow_print("\n>> [SYSTEM] %s, your ability is ready!", current->name);
                }
            }
        }
    | T_ID CHECKS T_STATUS SEMICOLON
        {
            if (strcmp($1, current->name) != 0) /* error handling */
                slow_print("\n>> [SYTEM-ERROR] It is not %s's turn! Wait for %s to finish.\n", $1, current->name);
            else {
                Character* opponent = get_opponent($1);

                printf("\n[%s]", get_char($1)->name);
                printf("\nRole: %s", current->role);
                printf("\nHP: %d", current->hp);
                printf("\nDamage: %d", current->damage);
                printf("\nSpeed: %d", current->speed);
                printf("\nIs defending? ");
                if(current->defending == 1 || current->defending == 2) printf("Yes");
                else printf("No");
                printf("\nHow many turns for your ability? ");
                if(current->cooldown < 0) printf("Used (One time only)");
                else if(current->cooldown == 0) printf("Ready");
                else printf("%d", current->cooldown);

                printf("\n");
                printf("\n[%s]", opponent->name);
                printf("\nRole: %s", opponent->role);
                printf("\nHP: %d", opponent->hp);
                printf("\nDamage: %d", opponent->damage);
                printf("\nSpeed: %d", opponent->speed);
                printf("\nIs defending? ");
                if(opponent->defending == 1 || opponent->defending == 2) printf("Yes");
                else printf("No");
                printf("\nHow many turns for your ability? ");
                if(current->cooldown < 0) printf("Used (One time only)");
                else if(current->cooldown == 0) printf("Ready");
                else printf("%d", opponent->cooldown);
                printf("\n");

                slow_print("\n>> [SYSTEM] Analysis complete. It is still %s's turn to act", current->name);
            }
        }
    ;

global:
    T_HELP SEMICOLON
    {
        printf("\n====================== RULES ======================"
                   "\nThe character with more speed begins the first attack"
                   "\nEvery character may use one action per round"
                   "\n\nEvery player can use the following commands:"
                   "\n\t -> ATTACK: "
                   "\n\t\t - Syntax: character1 attacks character2;"
                   "\n\t\t - This lowers the enemy's HP."
                   "\n\t -> ABILITY: "
                   "\n\t\t - Syntax: character1 uses ability on character2;"
                   "\n\t\t - The ability is based on the role:"
                   "\n\t\t\t * Mage: uses magic -> deals 150%% of their base damage."
                   "\n\t\t\t\t ** This ability has a cooldown of 2 turns."
                   "\n\t\t\t * Knight: uses slash -> deals 200%% of their base damage."
                   "\n\t\t\t\t ** This ability has a cooldown of 3 turns."
                   "\n\t\t\t * Thief: uses steal -> steals the weapon of its enemy, using its ability against them."
                   "\n\t\t\t\t ** This ability may be only used ONCE but defense is not useful against it. Anyway, think it through."
                   "\n\t -> DEFENSE: "
                   "\n\t\t - Syntax: character1 defends;"
                   "\n\t\t - This makes next attack the character receives be 50%% of the actual damage."
                   "\n\t\t - BONUS: a dice will be rolled, if the number is 4 or over, the round after it is also reduced 25%%!"
                   "\n\t -> FLEES: "
                   "\n\t\t - Syntax: character1 flees;"
                   "\n\t\t - This enters full gambling mode, here the speed is very important! A roulette will be turn to decide your fate."
                   "\n\t -> STATUS: "
                   "\n\t\t - Syntax: character1 checks status;"
                   "\n\t\t - This will print the character's status and all of their stats."
                   "\n\t -> QUIT: "
                   "\n\t\t - Syntax: quit;"
                   "\n\t\t - This options is used to quit the battle, but do not worry, only rats use this."
                   "\n\n Use the command help anytime if you want a refresh on the rules"
                   "\n==================================================\n");
        slow_print("\n>> [SYSTEM] Analysis complete. It is still %s's turn to act", current->name);
    }
    | T_QUIT SEMICOLON
    {
        slow_print("\n>> [NARRATOR] You coward! You shall never come ba...*glitches*"
                   "\n>> ... [SYSTEM] The simulation ends.\n");
        printf("\n============================================\n");
        free_characters();
        exit(0);
    }
    ;

/* ------------------------ */


%%


/* --------- MAIN ---------- */
int main(int argc, char **argv) {
    srand(time(NULL)); 

    // variable inicialization
    player1.hp = -1; player1.damage = -1; player1.speed = -1; player1.role = NULL;
    player2.hp = -1; player2.damage = -1; player2.speed = -1; player2.role = NULL;

    /* --- LÓGICA DE ENTRADA --- */
    FILE *target_file = NULL;
    int using_script = 0; 

    if (argc >= 2) {
        printf("\n>> [SYSTEM] Loading provided file: %s\n", argv[1]);
        target_file = fopen(argv[1], "r");
        using_script = 1;
    } else {
        const char* default_path = "Inputs/standard.txt";
        target_file = fopen(default_path, "r");
        
        if (target_file) {
            printf("\n>> [SYSTEM] No argument provided. Loading default: '%s'...\n", default_path);
            using_script = 1;
        } else {
            printf("\n>> [SYSTEM] No argument and no default file found.");
            printf("\n>> [SYSTEM] Listening to Standard Input...\n");
            yyin = stdin;
        }
    }

    if (target_file) {
        yyin = target_file;
    }
    /* ------------------------ */
    
    char response1;
    printf("\nWould you like to jump directly to the battle field? [y/n] ");
    scanf(" %c", &response1); 
    
    if(response1 == 'y' || response1 == 'Y') {
        printf("\n============================================");
        slow_print("\nJumping directly on the battle field\n");
        silent_mode = 1;
    } else 
        silent_mode = 0;
    

    if(silent_mode == 0) printf("==================== WELCOME =================");
    slow_print("\nWelcome to the rift fighters!"
            "\nThis adventure is dividied in two phases:"
            "\n\t 1. The system will register your characters."
            "\n\t 2. They will fight to DEATH!!!"
            "\nWe shall see who is the toughest one of all."
            "\nDuring the combat, if you are in need of aid just type 'help' to discover what your options are."
            "\nMay the odds be ever in your favor.");
    if(silent_mode == 0) printf("\n============================================\n");

    /* PHASE 1 */
    slow_print("\n--- PHASE 1: Loading Characters ---\n");

    if (yyparse() != 0) {
        printf("\n>> [FATAL ERROR] Error parsing characters. Exiting.\n");
        exit(1);
    }    

    slow_print("\nCharacters loaded successfully.\n");
    slow_print("\n--- PHASE 1 COMPLETE ---\n");
    if(silent_mode == 0) printf("\n============================================\n");

    char response2;
    slow_print("\n--- PHASE 2: Combat ---\n");
    
    if(silent_mode == 0) {
        slow_print("\n>> [SYSTEM] Let's go over the rules!"
                "\n>> [NARRATOR] ZZZzzz "
                "\n>> [SYSTEM] :( ... player, you want to hear the rules, right?..."
                "\n>> [y/n] ");
    } else 
        printf("\n>> [SYSTEM] Do you want to see the rules? [y/n] ");

    scanf(" %c", &response2);
    
    if(response2 == 'y' || response2 == 'Y'){
            silent_mode = 0; /* in case first answer was n */
            
            slow_print("\n>> [SYSTEM] :D Glad to hear that player!");
            slow_print("\n>> [NARRATOR] zzzzZZZZzzzzz\n");

            slow_print("\n====================== RULES ======================"
                        "\nThe character with more speed begins the first attack"
                        "\nEvery character may use one action per round"
                        "\n\nEvery player can use the following commands:"
                        "\n\t -> ATTACK: "
                        "\n\t\t - Syntax: character1 attacks character2;"
                        "\n\t\t - This lowers the enemy's HP."
                        "\n\t -> ABILITY: "
                        "\n\t\t - Syntax: character1 uses ability on character2;"
                        "\n\t\t - The ability is based on the role:"
                        "\n\t\t\t * Mage: uses magic -> deals 150%% of their base damage."
                        "\n\t\t\t\t ** This ability has a cooldown of 2 turns."
                        "\n\t\t\t * Knight: uses slash -> deals 200%% of their base damage."
                        "\n\t\t\t\t ** This ability has a cooldown of 3 turns."
                        "\n\t\t\t * Thief: uses steal -> steals the weapon of its enemy, using its ability against them."
                        "\n\t\t\t\t ** This ability may be only used ONCE, think it through."
                        );
            slow_print("\n\t -> DEFENSE: "
                        "\n\t\t - Syntax: character1 defends;"
                        "\n\t\t - This makes next attack the character receives be 50%% of the actual damage."
                        "\n\t\t - BONUS: a dice will be rolled, if the number is 4 or over, the round after it is also reduced 25%%!"
                        "\n\t -> FLEES: "
                        "\n\t\t - Syntax: character1 flees;"
                        "\n\t\t - This enters full gambling mode, here the speed is very important! A roulette will be turn to decide your fate."
                        "\n\t -> STATUS: "
                        "\n\t\t - Syntax: character1 checks status;"
                        "\n\t\t - This will print the character's status and all of their stats."
                        "\n\t -> QUIT: "
                        "\n\t\t - Syntax: quit;"
                        "\n\t\t - This options is used to quit the battle, but do not worry, only rats use this."
                        "\n\n Use the command help anytime if you want a refresh on the rules");
            printf("\n==================================================\n");
        } else {
            slow_print(">> [NARRATOR] Boring... Let's jump straight to violence then");
            slow_print("\n>> [SYSTEM] Skipping tutorial :(... I love rules...\n");
        }

    silent_mode = 0;    

    /* PHASE 2 */
    if(player1.speed >= player2.speed) current = &player1;
    else current = &player2;

    slow_print("\n>> [SYSTEM] Speed calculation complete. %s is faster!", current->name);
    slow_print("\n>> [SYSTEM] %s begins and may the odds be ever in your favor", current->name);
    slow_print("\n>> [NARRATOR] No more Hunger Games quotes please System");
    slow_print("\n>> [SYSTEM] :("); 

    while(1) {
        printf("\n\n-[%s]-> ", current->name); 
        fflush(stdout);
        
        int parse_status = yyparse();

        if (parse_status != 0) {            
            if (using_script) {
                slow_print("\n\n>> [SYSTEM] End of script file reached.");
                slow_print("\n>> [SYSTEM] Switching to MANUAL CONTROL. Fight for your life!\n");
                
                FILE *terminal = fopen("/dev/tty", "r");
                if (!terminal) {
                    printf("\n>> [ERROR] Could not access terminal. Exiting.\n");
                    break;
                }
                yyin = terminal;
                yyrestart(yyin); 
                using_script = 0; 
                
                continue; 
            } else 
                break;
        }
    }

    free_characters();
    return 0;
}

/* ------------------------ */

/* --------- AUXILIAR FUNCTIONS ---------- */

Character* get_char(char* name) {
    if (strcmp(player1.name, name) == 0) 
        return &player1;
    else if (strcmp(player2.name, name) == 0) 
        return &player2;
    
    return NULL; 
}

Character* get_opponent(char* name){
    if (strcmp(player1.name, name) == 0) 
        return &player2;
    else if (strcmp(player2.name, name) == 0) 
        return &player1;
    
    return NULL; 
}

Character* current_char() {
    return (char_count == 0) ? &player1 : &player2;
}

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
    printf("Try using the help command");
}

void slow_print(const char *format, ...) {
    va_list args;
    char buffer[1024]; 

    if(silent_mode == 1) return;
    
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

int ride_roulette(int success_chance) {
    const char spin_chars[] = {'|', '/', '-', '\\'}; 
    int final_roll = rand() % 100; 
    
    int is_success = (final_roll < success_chance);
    
    int loops = 30;     
    int delay = 20000; 

    printf("\n"); 

    for (int i = 0; i < loops; i++) {
        int visual_number = rand() % 100; 
        char spinner = spin_chars[i % 4];

        printf("\r\033[33m>> [ROULETTE] %c \033[0mSpeed Check: \033[36m%3d%%\033[0m needed | Rolling... \033[35m%3d%%\033[0m", 
               spinner, success_chance, visual_number);
        
        fflush(stdout); 
        usleep(delay);
        
        if (i > 20) delay += 50000;
        else delay += (i * 2000); 
    }

    if (is_success) {
        printf("\r\033[1;32m>> [ESCAPE] ✔ Speed Check: %3d%% needed | Rolled: %3d%% -> ESCAPED! \033[0m\n", 
               success_chance, final_roll);
    } else {
        printf("\r\033[1;31m>> [ESCAPE] ✘ Speed Check: %3d%% needed | Rolled: %3d%% -> FAILED!  \033[0m\n", 
               success_chance, final_roll);
    }
    
    usleep(500000); 
    
    return is_success;
}

int roll_dice() {
    const char* faces[] = { "?", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅" }; 
    
    int final_val = (rand() % 6) + 1; 
    int loops = 25;                   
    int delay = 20000;               

    printf("\n"); 

    for (int i = 0; i < loops; i++) {
        int visual_val = (rand() % 6) + 1;
        
        printf("\r\033[36m>> [DICE] Rolling... %s  [ %d ]\033[0m", faces[visual_val], visual_val);
        
        fflush(stdout); 
        usleep(delay);
        
        if (i > 15) delay += 40000; 
        else delay += 3000;
    }

    printf("\r\033[1;32m>> [DICE] Rolling... %s  -> RESULT: %d!   \033[0m\n", faces[final_val], final_val);
    
    usleep(300000); 
    
    return final_val;
}

void free_characters() {
    if (player1.name) { free(player1.name); player1.name = NULL; }
    if (player1.role && strcmp(player1.role, "invalid") != 0) { 
        free(player1.role); player1.role = NULL; 
    }

    if (player2.name) { free(player2.name); player2.name = NULL; }
    if (player2.role) { free(player2.role); player2.role = NULL; }
}