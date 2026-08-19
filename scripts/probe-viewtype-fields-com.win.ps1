param([string]4Alias='x1_21')
4ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function Decode-Utf8Base64 { param([string]4Value) [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(4Value)) }
4queries = @(
  (Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0Kwg0J/QldCg0JLQq9CVIDUg0JLQuNC00Ysu0JrQvtC0LCDQktC40LTRiy7QndCw0LjQvNC10L3QvtCy0LDQvdC40LUg0JjQlyDQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0JLQuNC00Ys='),
  (Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0Kwg0J/QldCg0JLQq9CVIDUg0JLQuNC00Ysu0JrQvtC0LCDQktC40LTRiy7QmNC80Y/Qn9GA0LXQtNC+0L/RgNC10LTQtdC70LXQvdC90YvRhdCU0LDQvdC90YvRhSDQmNCXINCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwINCa0JDQmiDQktC40LTRiw=='),
  (Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0Kwg0J/QldCg0JLQq9CVIDUg0JLQuNC00Ysu0JrQvtC0LCDQktC40LTRiy7Qn9GA0LXQtNC+0L/RgNC10LTQtdC70LXQvdC90YvQuSDQmNCXINCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwINCa0JDQmiDQktC40LTRiw=='),
  (Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0Kwg0J/QldCg0JLQq9CVIDUg0JLQuNC00Ysu0JrQvtC0LCDQktC40LTRiy7Qn9GA0LXQtNC+0L/RgNC10LTQtdC70LXQvSDQmNCXINCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwINCa0JDQmiDQktC40LTRiw==')
)
4ctx = Connect-1CFileBase -Alias 4Alias
4i=0
foreach(4qtxt in 4queries){ 4i++; try{ 4q=New-1CQuery -Connection 4ctx.Connection -Text 4qtxt; 4t=4q.Execute().Unload(); Write-Output("Q4i=OK Count=4(4t.Count())") } catch { Write-Output("Q4i=ERR 4(4_.Exception.Message)") } }
