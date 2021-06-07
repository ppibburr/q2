public class Bar {
  public static int[] ary() {
    int[] a;
    a = {1, 2, 3};
    return a;
  }
}
public class Foo : Bar {
  public delegate void moof_cb(int arg1);
  
  public static void moof(Foo.moof_cb cb) {
    cb(1);
  }
  
  public  Foo(int g, int  b) {
    int[] ba;  int[] a;
    ba = Bar.ary();
    for (var i_n=0; i_n < ba.length; i_n++) {
      var i = ba[i_n];
      print(i.to_string()+"\n");
    }
    a = {1, 2, 3};
    foreach ( var q in a )  { print(q.to_string()+"\n"); }
    var c = 0;
    var x = ((c != 0)) ? (1) : (2);
    var d = ((x > 1)) ? (5) : (((x == 2)) ? (6) : (7));
    var mbar = bar(d, 2);
    print(mbar[1].to_string()+"\n");
  }
  
  public static int[] bar(int a, int  b) {
    int[] c;
    c = Bar.ary();
    print("%d"+"\n",(a + b));
    c[1] = 8;
    moof( ( q) => { print(q.to_string()+"\n"); });
    return c;
  }
  
  public static void main() {
    new Foo(1, 2);
  }
}
