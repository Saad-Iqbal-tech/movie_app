import 'package:flutter/material.dart';


class Second extends StatelessWidget{
  
  Second({super.key});
  
  @override
  Widget build(BuildContext context){
    
    return Scaffold(
      appBar: AppBar(
        title: Text("page 2"),
      ),
      
      body:Center(
        child: ElevatedButton(onPressed: () => {
          Navigator.pushNamed(context, '/first')
        }, child: Text("Go to First Page"),),
      )
    );
  }
}