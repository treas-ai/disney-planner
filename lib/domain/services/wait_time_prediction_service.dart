enum MorningQueueVolatility { low, medium, high, extreme }

class WaitTimeEstimate {
 final int expectedMinutes; final int conservativeMinutes; final int upperBoundMinutes; final double confidence;
 const WaitTimeEstimate({required this.expectedMinutes,required this.conservativeMinutes,required this.upperBoundMinutes,this.confidence=0.8});
}

class WaitTimePredictionService {
 const WaitTimePredictionService();
 WaitTimeEstimate estimate({required int baseWaitMinutes, required MorningQueueVolatility volatility}) {
 int add=switch(volatility){MorningQueueVolatility.low=>5,MorningQueueVolatility.medium=>15,MorningQueueVolatility.high=>30,MorningQueueVolatility.extreme=>45};
 return WaitTimeEstimate(expectedMinutes: baseWaitMinutes, conservativeMinutes: baseWaitMinutes+add, upperBoundMinutes: baseWaitMinutes+add*2);
 }
}
