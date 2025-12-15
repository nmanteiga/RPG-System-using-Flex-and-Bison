/* rpg.h */
#ifndef RPG_H
#define RPG_H

typedef struct {
    char* name;      
    char* role;
    int hp;
    int damage;
    int speed;
    char* ability;  
} Character;

#endif