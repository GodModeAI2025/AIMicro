import Foundation
let launch=Date(timeIntervalSince1970:100),now=Date(timeIntervalSince1970:120)
func valid(_ running:Bool=true,_ pid:Int=42,_ modified:Double=110,_ expiry:Double=150)->Bool {currentPairing(running:running,ownedPID:42,configPID:pid,modified:Date(timeIntervalSince1970:modified),launched:launch,expires:Date(timeIntervalSince1970:expiry),now:now)}
precondition(valid())
precondition(!valid(false),"A stopped host must never re-display its QR")
precondition(!valid(true,43),"A different listener must not inherit QR state")
precondition(!valid(true,42,90),"Startup must reject previous launch configuration")
precondition(!valid(true,42,110,120),"Expired credentials must not be displayed")
print("PASS: stopped host, PID mismatch, stale startup config and expired QR are rejected")
