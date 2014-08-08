#!/usr/bin/env node
var child_process = require("child_process");
var fs = require("fs");
var isWin = process.platform.slice(0, 3) === "win";
var cmd = isWin ? "cca.cmd" : "cca";
if (!isWin && fs.existsSync(cmd)) { cmd = "./" + cmd }
var p = child_process.spawn(cmd, ["pre-prepare"], { stdio:"inherit" });
p.on("close", function(code) { process.exit(code); });