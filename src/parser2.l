/*
	PARSER-2
	(c) Eduardo Robsy Petrus, 2000-2010

	Functions:
		1.-Unroll REPT/ENDR macro
		2.-Manage nested REPT/ENDR
*/

%{
#include "asmsx.h"

#define P2_TEXT_SIZE 0x1000
#define P2_BUFF_SIZE 0x4000

static FILE *p2_output;
static char *p2_text, *p2_buffer;
static int p2_number, p2_lines, p2_level, p2_nested=0;

int prompt_error2(int);
%}

%option noinput nounput noyywrap

%s rept
%s repnum
%s line
%s final

%%

<INITIAL>"#"line[ \t]*[0-9]+\n	{
									safe_strcat(p2_text, yytext, P2_TEXT_SIZE, fname_src, -1);
									p2_lines = atoi(&yytext[5]);
									BEGIN(line);
								}

<line>.?rept[ \t]+				BEGIN(repnum);

<line>.							{
									safe_strcat(p2_text, yytext, P2_TEXT_SIZE, fname_src, -1);
									BEGIN(INITIAL);
								}

<repnum>[0-9]+[ \t]*			{
									p2_number = atoi(yytext);
									p2_buffer[0] = 0;
									p2_text[0] = 0;
									BEGIN(rept);
								}

<rept>.?rept[ \t]+[0-9]+[ \t]*	{
									p2_buffer = safe_strcat(p2_buffer, yytext, P2_BUFF_SIZE, fname_src, -1);
									p2_nested++;
									p2_level++;
								}

<rept>"#"line[ \t]*[0-9]+\n[ \t]*.?endr[ \t]*\n	{
													if (p2_nested)
													{
														p2_nested--;
														p2_buffer = safe_strcat(p2_buffer, yytext, P2_BUFF_SIZE, fname_src, -1);
													}
													else
													{
														int i;

														for (i = 0; i < p2_number; i++)
															fprintf(p2_output, "%s", p2_buffer);

														p2_buffer[0] = 0;
														BEGIN(INITIAL);
													}
												}

<rept>.							p2_buffer = safe_strcat(p2_text, yytext, P2_TEXT_SIZE, fname_src, -1);

<rept>\n						p2_buffer = safe_strcat(p2_buffer, yytext, P2_BUFF_SIZE, fname_src, -1);

<rept><<EOF>>					error_message(2, fname_src, -1);

<repnum>.						prompt_error2(1);

<INITIAL>\n						{
									fprintf(p2_output, "%s%s", p2_text, yytext);
									p2_text[0] = 0;
								}

<INITIAL>.						safe_strcat(p2_text, yytext, P2_TEXT_SIZE, fname_src, -1);

%%

int prompt_error2(int c)
{
	fprintf(stderr, ", line %d: ", p2_lines);
	switch (c)
	{
		case 1:
			fprintf(stderr, "number expected in REPT\n");
			break;
		case 2:
			fprintf(stderr, "REPT without ENDR\n");
			break;
		default:
			fprintf(stderr, "Unknown error in prompt_error2()\n");
	}
	fclose(p2_output);
	exit(c);
}

int preprocessor2()
{
	FILE *input;
	char *filename;
	int loop = 0;

	filename = malloc(PATH_MAX);
	p2_text = malloc(P2_TEXT_SIZE);
	p2_buffer = malloc(P2_BUFF_SIZE);
	p2_text[0] = 0;
	printf("Expanding system macros\n");

	do
	{
		snprintf(filename, PATH_MAX - 1, "~tmppre.%i", loop + 1);

		if ((input = fopen(filename, "r")) == NULL)
		{
			fprintf(stderr, "Fatal: cannot process file %s\n", filename);
			exit(1);
		}

		yyin = input;
 
		loop++;

		snprintf(filename, PATH_MAX - 1, "~tmppre.%i", loop + 1);

		p2_output = fopen(filename, "w");
		p2_level = 0;
		p2_nested = 0;

		yylex();

		fclose(input);
		fclose(p2_output);
	}
	while (p2_level);

/*
	free(filename);
	free(p2_text);
	free(p2_buffer);
*/
	return loop + 1;
}
