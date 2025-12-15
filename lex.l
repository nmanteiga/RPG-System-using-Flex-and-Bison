/* lex.l */
%{
#include <stdio.h>
#include <string.h>
#include "rpg.h"          
#include "gram.tab.h"   
%}

%option noyywrap

%%

    /* -------- PHASE 1 DEFINITIONS -------- */
"character"     { return T_CHARACTER; } 
"role"          { return T_ROLE; }    
"hp"            { return T_HP; }      
"damage"        { return T_DAMAGE; }  
"speed"         { return T_SPEED; }   

"{"             { return LBRACE; }  
"}"             { return RBRACE; }
"="             { return EQUALS; }
";"             { return SEMICOLON; }

    /* -------- PHASE 2 DEFINITIONS -------- */
"attacks"       { return T_ATTACKS; }
"defends"       { return T_DEFENDS; }
"flees"         { return T_FLEES; }
"uses"          { return USES; }     
"ability"       { return T_ABILITY; }
"checks"        { return CHECKS; }   
"status"        { return T_STATUS; }
"help"          { return T_HELP; }
"quit"          { return T_QUIT; }    
"on"            { return ON; }

    /* --------------------------------- */

[0-9]+                                   { yylval.intValue = atoi(yytext); return T_NUM; } 
[a-zA-ZáéíóúÁÉÍÓÚ][a-zA-ZáéíóúÁÉÍÓÚ0-9]* { yylval.strValue = strdup(yytext); return T_ID; } 


\"[^\"]*\"      { 
                  /* Saltamos las comillas al guardar */
                  yylval.strValue = strdup(yytext + 1); 
                  yylval.strValue[strlen(yylval.strValue)-1] = 0;
                  return T_STRING; 
                }

[ \t\n]         { /* ignore whitespace */ }
.               { printf("Unexpected token: %s\n", yytext); }

%%