postgres-driver.o: postgres-driver.c
	gcc -I/usr/include/postgresql -c postgres-driver.c -L/usr/lib/x86_64-linux-gnu -lpq -std=c99 -g

so: postgres-driver.o
	gcc -dynamiclib -shared -undefined postgres-driver.o -o ../postgres-driver.so -L/usr/lib/x86_64-linux-gnu -lpq -std=c99

clean:
	rm -f a.out postgres-driver.o ../postgres-driver.so
