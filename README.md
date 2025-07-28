<div align="center">

  <img src="./assets/logo.svg" alt="Logo" width="75%">

  [Intoxicode](https://intoxicode.arson.dev) is an [esolang](https://esolangs.org/wiki/Main_Page) that simulates a drunken program with uncertain behavior.

  <a href="https://intoxicode.arson.dev/docs">
    <img src="https://img.shields.io/static/v1?label=Docs&message=intoxicode.arson.dev/docs&color=F9AD6F">
  </a>
  <a href="https://github.com/tathyagarg/intoxicode/releases">
    <img src="https://shields.io/github/v/tag/tathyagarg/intoxicode?label=version&color=orange">
  </a>
  <a href="https://github.com/tathyagarg/intoxicode/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/tathyagarg/intoxicode?color=red">
  </a>
</div>

## Features
1. Statements ending with `.` are certain, `?` are uncertain.
2. There's a 10% chance for each character in a string literal to switch case.
3. Variable names must include vowels, it's too hard to pronounce otherwise.
4. Operations can be performed with `+`, `-`, `*`, `/`, and `%` operators, but reliable answers are not guaranteed.
5. Functions can be defined with `fun` and called with `function_name()`.
6. Comments can be added with `#` and will be ignored.
7. Exception prone code can be wrapped in `try` and `gotcha` blocks.
8. You can only have up to 25% of your code ending with `.` to keep it uncertain, given your code is at least 12 lines long. If exceeded, the certainty will be randomly decided for every line ending with `.` after the 25% is hit (i.e., if the first 4 lines of your code end with `.` and you have 16 lines, the first 4 lines execute as normal but if the 5th line ends with `.`, the `.` is ignored and a random certainty is assigned.
9. Any line can randomly be chosen to be skipped, simulating a drunken state.
10. Any line can randomly be chosen to be repeated, simulating a drunken state.
11. Information can be printed to the console with `scream` and information can be taken from stdin with `ask`.
12. Uncertain code ending with `?` will execute with a 75% chance of success. 

