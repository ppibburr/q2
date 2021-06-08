public class Foo {
  public int[] moof() {
    int[] a;
    a = {1, 2, 3};
    return a;
  }
  
  public virtual signal void foo(int a) {
    print("foo %d"+"\n",a);
  }
  
  public delegate void quux_cb(int a);
  
  public void quux(quux_cb cb) {
    foreach ( var q in moof() )  { cb(q); }
    foo(33);
  }
}
public class Bar : Foo {
  public int accessor { get; set; }
  
  public int reader { get; }
  
  public int writer { set; }
  
  public int _prop1;public int prop1 {
    get {
    return @_prop1;
  }
   set {
    @_prop1 = @value;
  } 
  }
  
  public  Bar(int a, string  b) {
    print(a.to_string()+"\n");
    print(b.to_string()+"\n");
    @accessor = 11;
    @_reader = 12;
    print("foo: %d"+"\n",@_accessor);
    @_accessor = 14;
    print("foo: %d"+"\n",@accessor);
    print("foo: %d"+"\n",@_reader);
    print("bar: %d"+"\n",@reader);
    print("each".to_string()+"\n");
    foreach ( var q in moof() )  { print(q.to_string()+"\n"); }
    print("for".to_string()+"\n");
    for (var i_n=0; i_n < moof().length; i_n++) {
      var i = moof()[i_n];
      print(i.to_string()+"\n");
    }
    @foo.connect( ( i) => { print("connect: %d"+"\n",i); });
    print("cb".to_string()+"\n");
    quux( ( n) => { print(n.to_string()+"\n"); });
  }
  
  public static void main() {
    new Bar(1, "two");
  }
}
