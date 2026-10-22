//! Focused tests of the analyzer on small projects written to a temp dir.

use luau_shield::config::Config;
use std::path::Path;

/// Writes `files` (path, content) into a temp dir and returns the findings as
/// `file:line:rule` strings (file relative to the temp dir).
fn run_with(files: &[(&str, &str)], config: &Config) -> Vec<String> {
    let dir = tempfile::tempdir().unwrap();
    for (path, content) in files {
        let full = dir.path().join(path);
        std::fs::create_dir_all(full.parent().unwrap()).unwrap();
        std::fs::write(full, content).unwrap();
    }
    let report = luau_shield::check(&[dir.path().to_path_buf()], config).unwrap();
    assert!(
        report.parse_failures.is_empty(),
        "{:?}",
        report.parse_failures
    );
    let root = dir.path().canonicalize().unwrap();
    report
        .findings
        .iter()
        .map(|f| {
            let file = Path::new(&f.file);
            let abs = if file.is_absolute() {
                file.to_path_buf()
            } else {
                std::env::current_dir().unwrap().join(file)
            };
            let rel = abs
                .canonicalize()
                .unwrap()
                .strip_prefix(&root)
                .unwrap()
                .to_string_lossy()
                .replace('\\', "/");
            format!("{rel}:{}:{}", f.span.line, f.rule)
        })
        .collect()
}

fn run(files: &[(&str, &str)]) -> Vec<String> {
    run_with(files, &Config::default())
}

#[test]
fn modern_syntax_parses_and_is_analysed() {
    let code = r#"--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
type Map<K, V> = { [K]: V }
export type Item = { name: string, price: number }
type function Identity(t)
	return t
end

local function id<T>(x: T): T
	return x
end

@native
local function scale(a: number, ...: number): number
	return a * 2
end

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Give") :: RemoteEvent
remote.OnServerEvent:Connect(function(player: Player, amount: number?, label: string)
	local doubled = if typeof(amount) == "number" then scale(amount) else 0
	local message = `{player.Name} gave {label}`
	local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue
	coins.Value += id(doubled)
	for i, v in { 1, 2, 3 } do
		if i > 1 then
			continue
		end
	end
	local t: Map<string, number> = {}
	t[message] //= 2
end)
"#;
    let findings = run(&[("Give.server.luau", code)]);
    assert_eq!(findings, ["Give.server.luau:23:luau-shield001"]);
}

#[test]
fn compound_and_plain_assignment_paths() {
    let code = r#"
local Remotes = game:GetService("ReplicatedStorage").Remotes
Remotes.A.OnServerEvent:Connect(function(player, n)
	player.leaderstats.Cash.Value = player.leaderstats.Cash.Value + n
end)
Remotes.B.OnServerEvent:Connect(function(player, n)
	local stats = player:FindFirstChild("leaderstats")
	local gems = stats and stats:FindFirstChild("Gems")
	if gems then
		gems.Value -= n
	end
end)
"#;
    assert_eq!(
        run(&[("s.server.luau", code)]),
        [
            "s.server.luau:4:luau-shield001",
            "s.server.luau:10:luau-shield001"
        ]
    );
}

#[test]
fn rojo_require_and_string_require() {
    let project = r#"{
  "name": "game",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": { "$path": "src/server" },
    "ReplicatedStorage": { "Shared": { "$path": "src/shared" } }
  }
}"#;
    let economy = r#"
local Economy = {}
function Economy.give(player: Player, amount: number)
	player.leaderstats.Coins.Value += amount
end
return Economy
"#;
    let validate = r#"
local Validate = {}
function Validate.amount(value: unknown): boolean
	return typeof(value) == "number" and value == value and value > 0 and value <= 100
end
return Validate
"#;
    let main = r#"
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ServerScriptService.Server.Economy)
local Validate = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Validate"))
local Util = require("./Util")
ReplicatedStorage.Remotes.Bad.OnServerEvent:Connect(function(player, amount)
	Economy.give(player, amount)
end)
ReplicatedStorage.Remotes.Good.OnServerEvent:Connect(function(player, amount)
	if not Validate.amount(amount) then
		return
	end
	Economy.give(player, amount)
end)
ReplicatedStorage.Remotes.Util.OnServerEvent:Connect(function(player, amount)
	Util.save(player, amount)
end)
"#;
    let util = r#"
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("Saves")
local last = {}
return {
	save = function(player, value)
		if last[player] and os.clock() - last[player] < 5 then return end
		last[player] = os.clock()
		store:SetAsync(tostring(player.UserId), value)
	end,
}
"#;
    let findings = run(&[
        ("default.project.json", project),
        ("src/server/Economy.luau", economy),
        ("src/shared/Validate.luau", validate),
        ("src/server/Main.server.luau", main),
        ("src/server/Util.luau", util),
    ]);
    assert_eq!(
        findings,
        [
            "src/server/Economy.luau:4:luau-shield001",
            "src/server/Util.luau:9:luau-shield001"
        ]
    );
}

#[test]
fn script_parent_require_without_project() {
    let helper = r#"
local M = {}
function M.run(code)
	return loadstring(code)
end
return M
"#;
    let main = r#"
local M = require(script.Parent.Helper)
game.ReplicatedStorage.Exec.OnServerEvent:Connect(function(player, code)
	M.run(code)()
end)
"#;
    assert_eq!(
        run(&[
            ("server/Helper.luau", helper),
            ("server/Main.server.luau", main)
        ]),
        ["server/Helper.luau:4:luau-shield004"]
    );
}

#[test]
fn knit_client_methods_are_sources() {
    let code = r#"
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local ShopService = Knit.CreateService({ Name = "ShopService", Client = {} })
function ShopService.Client:Buy(player: Player, amount: number)
	player.leaderstats.Coins.Value -= amount
end
return ShopService
"#;
    assert_eq!(
        run(&[("server/ShopService.luau", code)]),
        ["server/ShopService.luau:5:luau-shield001"]
    );
}

#[test]
fn t_library_checks() {
    let code = r#"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local t = require(ReplicatedStorage.Packages.t)
local typeOnly = t.tuple(t.string, t.number)
local strict = t.tuple(t.string, t.numberConstrained(1, 10))
ReplicatedStorage.Remotes.A.OnServerEvent:Connect(function(player, item, qty)
	if not typeOnly(item, qty) then return end
	player.leaderstats.Coins.Value -= qty
end)
ReplicatedStorage.Remotes.B.OnServerEvent:Connect(function(player, item, qty)
	if not strict(item, qty) then return end
	player.leaderstats.Coins.Value -= qty
end)
"#;
    assert_eq!(
        run(&[("s.server.luau", code)]),
        ["s.server.luau:8:luau-shield001"]
    );
}

#[test]
fn suppressions_and_config() {
    let code = r#"
game.ReplicatedStorage.A.OnServerEvent:Connect(function(player, n)
	player.leaderstats.Coins.Value += n -- luau-shield-ignore: luau-shield001 audited
	-- luau-shield-ignore: luau-shield002 teleport pads are trusted here
	player.Character.HumanoidRootPart.CFrame = n
	player.Character.Humanoid.WalkSpeed = n
end)
"#;
    assert_eq!(
        run(&[("s.server.luau", code)]),
        ["s.server.luau:6:luau-shield002"]
    );
    let mut config =
        Config::from_toml("[rules]\nluau-shield002 = \"off\"", Path::new(".")).unwrap();
    assert!(run_with(&[("s.server.luau", code)], &config).is_empty());
    config = Config::from_toml(
        "[[sinks]]\nfunction = \"Economy.add\"\nrule = \"luau-shield001\"\narguments = [2]\n[[sanitizers]]\nfunction = \"Guard.amount\"",
        Path::new("."),
    )
    .unwrap();
    let custom = r#"
local Economy = require(game.ServerStorage.Economy)
local Guard = require(game.ServerStorage.Guard)
game.ReplicatedStorage.A.OnServerEvent:Connect(function(player, n)
	Economy.add(player, n)
end)
game.ReplicatedStorage.B.OnServerEvent:Connect(function(player, n)
	if not Guard.amount(n) then return end
	Economy.add(player, n)
end)
"#;
    assert_eq!(
        run_with(&[("c.server.luau", custom)], &config),
        ["c.server.luau:5:luau-shield001"]
    );
}

#[test]
fn client_files_are_not_server_analysed_but_secrets_are_found() {
    let client = r#"
local coins = game.Players.LocalPlayer.leaderstats.Coins
game.ReplicatedStorage.A.OnClientEvent:Connect(function(n)
	coins.Value += n
end)
local WEBHOOK = "https://discord.com/api/webhooks/123456789012345678/abcdefghijklmnopqrstuvwxyzABCDEFGH0123456789"
"#;
    let server = r#"
local WEBHOOK = "https://discord.com/api/webhooks/123456789012345678/abcdefghijklmnopqrstuvwxyzABCDEFGH0123456789"
"#;
    assert_eq!(
        run(&[("ui.client.luau", client), ("log.server.luau", server)]),
        ["ui.client.luau:6:luau-shield008"]
    );
}

#[test]
fn instance_ownership() {
    let code = r#"
local Remotes = game:GetService("ReplicatedStorage").Remotes
Remotes.Drop.OnServerEvent:Connect(function(player, tool)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then return end
	tool:Destroy()
end)
Remotes.Drop2.OnServerEvent:Connect(function(player, tool)
	if typeof(tool) ~= "Instance" or not tool:IsDescendantOf(player.Backpack) then return end
	tool:Destroy()
end)
Remotes.Open.OnServerEvent:Connect(function(player, door)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (door.Position - root.Position).Magnitude > 10 then return end
	door.CanCollide = false
end)
Remotes.Chest.OnServerEvent:Connect(function(player, chest)
	if not chest:IsA("Model") then return end
	player.leaderstats.Coins.Value += chest:GetAttribute("Reward")
	chest:Destroy()
end)
"#;
    assert_eq!(
        run(&[("s.server.luau", code)]),
        [
            "s.server.luau:5:luau-shield003",
            "s.server.luau:18:luau-shield003"
        ]
    );
}

#[test]
fn rate_limit_and_invoke_client() {
    let code = r#"
local Remotes = game:GetService("ReplicatedStorage").Remotes
local store = game:GetService("DataStoreService"):GetDataStore("x")
Remotes.Save.OnServerEvent:Connect(function(player)
	store:SetAsync(player.UserId, 1)
end)
local last = {}
Remotes.Save2.OnServerEvent:Connect(function(player)
	if last[player] and os.clock() - last[player] < 3 then return end
	last[player] = os.clock()
	store:SetAsync(player.UserId, 1)
end)
local busy = {}
Remotes.Save3.OnServerEvent:Connect(function(player)
	if busy[player] then return end
	busy[player] = true
	store:SetAsync(player.UserId, 1)
	busy[player] = nil
end)
Remotes.Ask.OnServerEvent:Connect(function(player)
	local answer = Remotes.Question:InvokeClient(player)
	player.leaderstats.Coins.Value += answer
end)
task.spawn(function()
	Remotes.Question:InvokeClient(game.Players:GetPlayers()[1])
end)
"#;
    assert_eq!(
        run(&[("s.server.luau", code)]),
        [
            "s.server.luau:4:luau-shield007",
            "s.server.luau:21:luau-shield006",
            "s.server.luau:22:luau-shield001"
        ]
    );
}

#[test]
fn http_and_text() {
    let code = r#"
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Remotes = game:GetService("ReplicatedStorage").Remotes
local last = {}
Remotes.Report.OnServerEvent:Connect(function(player, msg, id)
	if last[player] and os.clock() - last[player] < 10 then return end
	last[player] = os.clock()
	HttpService:PostAsync("https://example.com/hook", HttpService:JSONEncode({ content = msg }))
	HttpService:GetAsync("https://api.example.com/users/" .. id)
	HttpService:GetAsync("https://api.example.com/users/" .. HttpService:UrlEncode(id))
	if typeof(msg) == "string" and #msg <= 200 then
		HttpService:PostAsync("https://example.com/hook", HttpService:JSONEncode({ content = msg }))
	end
end)
Remotes.Sign.OnServerEvent:Connect(function(player, text)
	local sign = workspace.Sign.SurfaceGui.TextLabel
	sign.Text = text
	local result = TextService:FilterStringAsync(text, player.UserId)
	sign.Text = result:GetNonChatStringForBroadcastAsync()
end)
"#;
    assert_eq!(
        run(&[("s.server.luau", code)]),
        [
            "s.server.luau:9:luau-shield005",
            "s.server.luau:10:luau-shield005",
            "s.server.luau:16:luau-shield007",
            "s.server.luau:18:luau-shield002"
        ]
    );
}

#[test]
fn handlers_in_tables_varargs_and_invoke() {
    let code = r#"
local Remotes = game:GetService("ReplicatedStorage").Remotes
local Handlers = {}
function Handlers.Give(player, amount)
	player.leaderstats.Coins.Value += amount
end
function Handlers.Hello(player)
	print(player.Name)
end
for name, handler in Handlers do
	Remotes[name].OnServerEvent:Connect(handler)
end
Remotes.Get.OnServerInvoke = function(player, ...)
	local args = { ... }
	player.leaderstats.Gems.Value = args[1]
	return true
end
Remotes.Chat.OnServerEvent:Connect(function(...)
	local player, cmd = ...
	loadstring(cmd)()
end)
"#;
    assert_eq!(
        run(&[("s.server.luau", code)]),
        [
            "s.server.luau:5:luau-shield001",
            "s.server.luau:15:luau-shield001",
            "s.server.luau:20:luau-shield004"
        ]
    );
}

#[test]
fn chatted_inside_player_added() {
    let code = r#"
local Players = game:GetService("Players")
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if message:sub(1, 5) == "/run " then
			loadstring(message:sub(6))()
		end
	end)
end)
"#;
    assert_eq!(
        run(&[("s.server.luau", code)]),
        ["s.server.luau:6:luau-shield004"]
    );
}

#[test]
fn deep_recursion_and_big_files_terminate() {
    let mut code = String::from(
        "local R = game.ReplicatedStorage\nlocal function f(n, x) if n > 0 then return f(n - 1, x) end return x end\n",
    );
    for i in 0..300 {
        code.push_str(&format!(
            "R.E{i}.OnServerEvent:Connect(function(p, a) if a > {i} then p.leaderstats.Coins.Value += f(3, a) end end)\n"
        ));
    }
    let start = std::time::Instant::now();
    let findings = run(&[("big.server.luau", &code)]);
    assert_eq!(findings.len(), 300);
    assert!(start.elapsed().as_secs() < 20);
}

#[test]
fn oop_classes_with_metatables() {
    let code = r#"
local Shop = {}
Shop.__index = Shop

function Shop.new(owner: Player)
	local self = setmetatable({}, Shop)
	self.owner = owner
	return self
end

function Shop:Deposit(amount: number)
	self.owner.leaderstats.Coins.Value += amount
end

function Shop:SafeDeposit(amount: unknown)
	if typeof(amount) ~= "number" or amount ~= amount or amount < 1 or amount > 10 then
		return
	end
	self.owner.leaderstats.Coins.Value += amount
end

local Remotes = game:GetService("ReplicatedStorage").Remotes
Remotes.Deposit.OnServerEvent:Connect(function(player, amount)
	local shop = Shop.new(player)
	shop:Deposit(amount)
	shop:SafeDeposit(amount)
end)
"#;
    assert_eq!(
        run(&[("s.server.luau", code)]),
        ["s.server.luau:12:luau-shield001"]
    );
}

#[test]
fn conditions_stored_in_variables() {
    let code = r#"
local Remotes = game:GetService("ReplicatedStorage").Remotes
local function isValidAmount(n: unknown): boolean
	return typeof(n) == "number" and n == n and n >= 1 and n <= 50
end
Remotes.A.OnServerEvent:Connect(function(player, amount)
	local ok = isValidAmount(amount)
	if not ok then return end
	player.leaderstats.Coins.Value += amount
end)
Remotes.B.OnServerEvent:Connect(function(player, amount)
	local valid = typeof(amount) == "number" and amount == amount and amount > 0 and amount < 10
	if valid then
		player.leaderstats.Coins.Value += amount
	end
end)
Remotes.C.OnServerEvent:Connect(function(player, amount)
	local valid = typeof(amount) == "number"
	if valid then
		player.leaderstats.Coins.Value += amount
	end
end)
"#;
    assert_eq!(
        run(&[("s.server.luau", code)]),
        ["s.server.luau:20:luau-shield001"]
    );
}
