open Syntax

type example = { name : string; pre : assertion; program : program; post : assertion }
let p ?(apis=[]) ?(bound=8) body = {body; apis; loop_bound=bound}

let safe_div = { name="safe_div"; params=["x";"y"];
  pre=Var "y" <>: Int 0; post=Var "result" =: Binop(Div,Var "x",Var "y") }

let verified = [
  { name="absolute value is nonnegative"; pre=True;
    program=p (If (Var "x" >=: Int 0, Assign("y",Var "x"), Assign("y",Neg(Var "x"))));
    post=Var "y" >=: Int 0 };
  { name="increment"; pre=Var "x" >=: Int 0;
    program=p (Assign("x",Var "x" +: Int 1)); post=Var "x" >: Int 0 };
  { name="memory round trip"; pre=True;
    program=p (Seq [Store(Var "a",Int 42); Assign("x",Load(Var "a"))]);
    post=Var "x" =: Int 42 };
  { name="safe API call"; pre=Var "b" <>: Int 0;
    program=p ~apis:[safe_div] (Call("z","safe_div",[Var "a";Var "b"]));
    post=Var "z" =: Binop(Div,Var "a",Var "b") };
  { name="bounded countdown"; pre=And [Var "x" >=: Int 0; Var "x" <=: Int 3];
    program=p ~bound:4 (While {guard=Var "x" >: Int 0; body=Assign("x",Var "x" -: Int 1); invariant=None});
    post=Var "x" =: Int 0 };
]

let buggy = [
  { name="strict absolute value"; pre=True;
    program=p (If (Var "x" >: Int 0, Assign("y",Var "x"), Assign("y",Neg(Var "x"))));
    post=Var "y" >: Int 0 };
  { name="wrong increment claim"; pre=True;
    program=p (Assign("y",Var "x" +: Int 1)); post=Var "y" >: Var "x" +: Int 1 };
  { name="uninitialised memory assumption"; pre=True;
    program=p (Assign("x",Load(Var "a"))); post=Var "x" =: Int 0 };
  { name="unsafe API call"; pre=True;
    program=p ~apis:[safe_div] (Call("z","safe_div",[Var "a";Var "b"])); post=True };
  { name="wrong stored value"; pre=True;
    program=p (Seq [Store(Var "a",Int 7); Assign("x",Load(Var "a"))]); post=Var "x" =: Int 8 };
]

