## Ladění helm chartů
Pro ladění helm chartů je připravena možnost renderování nepublikovaných vývojových verzí helm chartů z lokálního disku. Prerekvizitou je následující postup.  

Příprava helm chartu probíhá standardním způsobem, jen lokálně (nikoliv v rámci CI pipeline). V adresáři s helm chartem (jedním či více) je potřeba vytvořit helm index pomocí příkazu `helm repo index <DIR>`.
```sh
helm repo index $DIR
#V adresáři v helm charty a indexem $DIR  je potřeba spustit HTTP server na portu $PORT - např. `cd <DIR>; python -m SimpleHTTPServer <PORT>`
cd $DIR; python -m SimpleHTTPServer $PORT
#Vytvořené Helm repository je nakonec potřeba nastavit:
helm repo add <REPONAME> http://localhost:$PORT
```
