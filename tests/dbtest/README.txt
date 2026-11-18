# Veri katmani testi (journal/debounce/kurtarma)
exe/Program.cs icindeki "Veritabani katmani" ve "Anlik goruntuler" bloklari JavaScriptSerializer yerine System.Text.Json shim ile calistirilir.
Calistirma: tests/dbtest/gen.sh   (exe/Program.cs bloklarini otomatik cikarir ve .NET 10 uzerinde calistirir)
