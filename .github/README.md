rpgle-repl is a REPL tool for the RPG language on IBM i. A REPL (Read-Evaluate-Print-Loop) program allows you to code small snippets and get immediate feedback on their execution.

# Why rpgle-repl?

Some of my most frequently asked questions are "how do these %BIFs (built in functions) respond to different inputs?" and "how do I write a free-format equivalent to this fixed format code?". To answer them, I would inevitably write a small program, set a breakpoint, and run it in debug to evaluate whichever variable I cared about at runtime.

rpgle-repl streamlines this process - not only automatically compiling snippets of code, but also dynamically recording changed variables and displaying the results on screen.

Check out this basic example:
![Short GIF of REPL evaluating various values](/.github/readme-media/repl-in-action.gif)

Thanks for visiting!

![Example of REPL showing results detailing the repo details](/.github/readme-media/rpgle-repl-details.png)

Find out more about installing and using rpgle-repl in the [wiki](https://github.com/tom-writes-code/rpgle-repl/wiki).
