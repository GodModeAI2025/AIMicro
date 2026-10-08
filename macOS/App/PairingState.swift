import Foundation
func currentPairing(running:Bool,ownedPID:Int,configPID:Int,modified:Date,launched:Date,expires:Date,now:Date)->Bool {
 running && ownedPID > 0 && configPID == ownedPID && modified >= launched && expires > now
}
