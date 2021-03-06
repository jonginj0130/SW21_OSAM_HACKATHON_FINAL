import 'package:flutter/material.dart';
import 'package:mypt/theme.dart';

class LeaderBoardTile extends StatelessWidget {
  final String? userName;
  final int? score;
  final int? rank;

  LeaderBoardTile({
    required this.userName,
    required this.score,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(5.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      height: 60,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: kBlueColor, width: 0.5),
            borderRadius: BorderRadius.circular(25)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kBlueColor,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    '$userName',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kBlueColor,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '$score',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kBlueColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
