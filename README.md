This project contains a REPL tool for the RPG language on IBM i. A REPL (Read-Evaluate-Print-Loop) program allows you to code small snippets and get immediate feedback on their execution.

[TOC]

## Building

To build this project, you need to install the [Bob build tool](https://github.com/IBM/ibmi-bob). Then:

- Clone this repository onto the IFS of your IBM i
- Set `curlib` and `objlib` to the library you wish to hold the built objects.
- From the root directory, run the command `makei all`.

## Launching

Once REPL is installed, you can launch it through the IBM i command `REPL`.

## How to Use

REPL allows you to enter short snippets of RPG code into an interactive session and immediately evaluate the results. It achieves this by creating a temporary RPG program based on your snippet and dynamically inserting statements to record the values of variables as they change. After execution, the original snippet and stored results are displayed side-by-side.

This immediate feedback is extremely useful in helping developers become comfortable with unfamiliar concepts.

### Declaring variables

REPL supports both free and fixed format RPG, determining the type based on the first character of each line. Any line with a capital letter corresponding to a fixed format specification (`HFDICOP`) in the first column is treated as fixed format, otherwise free format is assumed.

Fixed format code is only partially supported, and will not be able to return the same level of feedback as free format code, as shown in the following example.

![Example showing the declaration of two variables in REPL - one using free format, and one using fixed format. The free format variable is evaluated, and the result is shown on screen. The fixed format variable cannot be evaluated.](/readme-media/declaring-free-and-fixed-variables.png)

### Evaluation

After building a snippet, evaluation is triggered by taking `F11`. This will create, compile, and execute the evaluating program. If this is successful, the message `Program ran successfully` is shown on screen.

#### Evaluation types

REPL will evaluate a variable whenever it is changed by a free format RPG statement. Values changed as part of a fixed format statement, or as part of an embedded SQL statement will not be evaluated.

In addition, REPL records how many times a loop was executed, and the SQL state and code after any SQL statement. In the case that a variable has been executed multiple times within a loop, each individual evaluation is shown.

![Example showing an evaluation of an SQL statement within a do-while loop. The number of times the loop was executed is shown, along with the value of the variable after each iteration. An SQL statement also shows the sql state and sql code.](/readme-media/executing-loops-and-sql-statements.png)

#### Investigating problems

If REPL is unable to compile the evaluating program, the message `Module not created. F7 to check spool files, F17 to view generated source` is shown. A similar message is shown if the module compiles normally, but the program cannot be created.

![](/readme-media/unable-to-compile.png)

In this case, you will be directed to take `F7` to view the spool files to identify any problems. The spool files for compilation are named `REPL_SRC` and `REPL_MOD`.

Alternatively, taking `F17` will display the temporary source generated for the evaluating program. This help to identify if the problem is within the snippet, or if REPL has introduced a coding defect while creating the evaluating program.

#### Binding service programs

REPL can be used to bind in a service program as an easy way to access exported procedures. To help with this, reference source can be included using `/copy <library>/<file>,<member>` or `/include <library>/<file>,<member>`.

![Example showing a reference source being included in the snippet with a procedure declared in the prototype being called.](/readme-media/adding-reference-source.png)

If reference source is included, REPL will assume that a service program should be bound, and will attempt to find a service program in the libary list with the same name as the member. If no such service program is found, the `CRTPGM` command will be shown, prompting the user to replace or remove the service program.

Alternatively, `F23` can be used to access the `CRTSQLRPGI` and `CRTPGM` commands to allow amendments before submitting them.

#### Debug mode

Sometimes it is useful to add a breakpoint to be able to debug the evaluating program. This may be especially true for stepping through calls to exported procedures in bound service programs. To do this, the create, compile and execute function provided by `F11` can be broken down:

1. Take `F10` to create and compile the evaluating program
2. Take `F2` to start a debug session over the evaluating program
3. Place all required breakpoints, and return to REPL with `F12`
4. Execute the current evaluating program by taking `F12`

![Example showing a simple snippet and the corresponding debug session](/readme-media/debug-session.png)

### Navigating the screen

Several function keys have been provided to help format and manipulate snippets.

- `F6` - Insert a new line after the current cursor location, and move the cursor to that line
- `F14` - Delete the line the cursor is currently on
- `F15` - Split the line the cursor is currently on, moving text to the right of the cursor to a new line

Function key `F1` is used to show extended results, where there is not enough space to show the full result on the main REPL screen.

![Example showing a long result visible via the F1 key. In the background, you can see that this result did not fit on screen on the main REPL homepage.](/readme-media//long-result.png)

#### Line limit

New snippets are created with 51 lines available for editing. Pressing enter at any time will add or remove lines to ensure that there are always 51 blank lines available in REPL.

#### Clearing, saving, and loading snippets

The current snippet can be cleared by taking `F5`. This will permanently remove the existing snippet, and return REPL to displaying an empty snippet.

##### Save and Load Snippets

Exiting REPL will store the current snippet as an "unsaved snippet". This will still be accessible if you reopen REPL within the same session. If you reopen a snippet in this way and make changes, the original snippet will be lost.

You can choose to save individual snippets which you do not wish to be changed by taking `F21`, and adding a suitable name for the snippet.

`F21` also provides the option to load snippets. Initially, you are shown a list of your saved snippets. It is possible from here to view saved snippets belonging to other users, or all unsaved snippets. A short preview of the snippet is shown on screen, along with the date the snippet was created.

![A list of saved snippets in REPLLOAD belonging to the current user (REPL). The snippet is named "Greeting", and a previewe of the first few lines of the snippet is shown.](/readme-media/replload-saved-snippet.png)

From here, individual snippets can be loaded to the current session, or deleted entirely. Other users snippets can be viewed and loaded, but you are only able to delete your own snippets.

#### Fixed format rulers

When entering fixed format code, you can add an on-screen ruler by taking `F4`. This will display a temporary column guide which will be cleared before evaluation.

![Example showing REPL with a D-spec fixed format ruler on screen to help define a variable](/readme-media/fixed-format-ruler.png)
