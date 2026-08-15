final List<Map<String, dynamic>> mockHdfcSms = [
  // 1. UPI Debit
  {'body': 'Rs.340.00 debited from A/c XX1234 on 04-03-26 to SWIGGY via UPI Ref 421874651243. Avl bal:Rs.42,340.00', 'expectedAmount': 340.00, 'expectedDirection': 'debit', 'expectedRecipient': 'SWIGGY', 'expectedRef': '421874651243'},
  // 2. UPI Credit
  {'body': 'Rs.1500.00 credited to A/c XX1234 on 04-03-26 via UPI from JOHN DOE. Ref 521874651244. Bal:Rs.43,840.00', 'expectedAmount': 1500.00, 'expectedDirection': 'credit', 'expectedRecipient': 'JOHN DOE', 'expectedRef': '521874651244'},
  // 3. ATM Withdrawal
  {'body': 'Rs.2000.00 withdrawn from A/c XX1234 at ATM on 04-03-26. Avl Bal:Rs.41,840.00', 'expectedAmount': 2000.00, 'expectedDirection': 'debit', 'expectedRecipient': 'ATM', 'expectedRef': null},
  // 4. NEFT Credit
  {'body': 'Rs.45000.00 credited to A/c XX1234 on 04-03-26 by NEFT from EMPLOYER INC. Ref:N042611234. Bal:Rs.86,840.00', 'expectedAmount': 45000.00, 'expectedDirection': 'credit', 'expectedRecipient': 'EMPLOYER INC', 'expectedRef': 'N042611234'},
  // 5. IMPS Debit
  {'body': 'Rs.1,000.00 debited from A/c XX1234 on 05-03-26 to MOBILE RECHARGE via IMPS. Ref: 621874651245. Bal:Rs.85,840.00', 'expectedAmount': 1000.00, 'expectedDirection': 'debit', 'expectedRecipient': 'MOBILE RECHARGE', 'expectedRef': '621874651245'},
  // 6. Spent (Card)
  {'body': 'Rs.500.00 spent on A/c XX1234 on 05-03-26 at RELIANCE RETAIL. Bal:Rs.85,340.00', 'expectedAmount': 500.00, 'expectedDirection': 'debit', 'expectedRecipient': 'RELIANCE RETAIL', 'expectedRef': null},
  // 7. INR Format
  {'body': 'INR 120.00 debited from A/c XX1234 on 05-03-26 to ZOMATO via UPI Ref 721874651246. Avl bal:INR 85,220.00', 'expectedAmount': 120.00, 'expectedDirection': 'debit', 'expectedRecipient': 'ZOMATO', 'expectedRef': '721874651246'},
  // 8. Cash Deposit
  {'body': 'Rs.2,500.00 credited to A/c XX1234 on 06-03-26 from CASH DEPOSIT. Bal:Rs.87,720.00', 'expectedAmount': 2500.00, 'expectedDirection': 'credit', 'expectedRecipient': 'CASH DEPOSIT', 'expectedRef': null},
  // 9. Debit without decimal
  {'body': 'Rs.80 debited from A/c XX1234 on 06-03-26 to TEA STALL via UPI Ref 821874651247. Avl bal:Rs.87,640', 'expectedAmount': 80.00, 'expectedDirection': 'debit', 'expectedRecipient': 'TEA STALL', 'expectedRef': '821874651247'},
  // 10. Large Amount
  {'body': 'Rs.1,00,000.00 debited from A/c XX1234 on 06-03-26 to RENT. Ref: 921874651248. Bal:Rs.75,640.00', 'expectedAmount': 100000.00, 'expectedDirection': 'debit', 'expectedRecipient': 'RENT', 'expectedRef': '921874651248'},
  // 11. No ref
  {'body': 'Rs.150.50 debited from A/c XX1234 on 07-03-26 to METRO. Avl bal:Rs.75,490.00', 'expectedAmount': 150.50, 'expectedDirection': 'debit', 'expectedRecipient': 'METRO', 'expectedRef': null},
  // 12. Special chars in merchant
  {'body': 'Rs.450.00 debited from A/c XX1234 on 07-03-26 to JIO&CO-STORE via UPI Ref 021874651249. Avl bal:Rs.75,040.00', 'expectedAmount': 450.00, 'expectedDirection': 'debit', 'expectedRecipient': 'JIO&CO-STORE', 'expectedRef': '021874651249'},
  // 13. Another card spend
  {'body': 'Rs.3000.00 spent on A/c XX1234 on 07-03-26 at SHELL PETROL PUMP. Bal:Rs.72,040.00', 'expectedAmount': 3000.00, 'expectedDirection': 'debit', 'expectedRecipient': 'SHELL PETROL PUMP', 'expectedRef': null},
  // 14. Refund
  {'body': 'Rs.200.00 credited to A/c XX1234 on 08-03-26 from REFUND/AMAZON via UPI Ref 121874651250. Bal:Rs.72,240.00', 'expectedAmount': 200.00, 'expectedDirection': 'credit', 'expectedRecipient': 'REFUND/AMAZON', 'expectedRef': '121874651250'},
  // 15. Standard Debit
  {'body': 'Rs.600.00 debited from A/c XX1234 on 08-03-26 to AMAZON WEB via UPI Ref 221874651251. Avl bal:Rs.71,640.00', 'expectedAmount': 600.00, 'expectedDirection': 'debit', 'expectedRecipient': 'AMAZON WEB', 'expectedRef': '221874651251'},
  // 16. ATM large
  {'body': 'Rs.5,000.00 withdrawn from A/c XX1234 at ATM on 08-03-26. Avl Bal:Rs.66,640.00', 'expectedAmount': 5000.00, 'expectedDirection': 'debit', 'expectedRecipient': 'ATM', 'expectedRef': null},
  // 17. Small amount
  {'body': 'Rs.15.00 debited from A/c XX1234 on 09-03-26 to PAN SHOP via UPI Ref 321874651252. Avl bal:Rs.66,625.00', 'expectedAmount': 15.00, 'expectedDirection': 'debit', 'expectedRecipient': 'PAN SHOP', 'expectedRef': '321874651252'},
  // 18. Groceries
  {'body': 'Rs.1200.00 debited from A/c XX1234 on 09-03-26 to GROCERIES. Bal:Rs.65,425.00', 'expectedAmount': 1200.00, 'expectedDirection': 'debit', 'expectedRecipient': 'GROCERIES', 'expectedRef': null},
  // 19. No decimals
  {'body': 'Rs.50 debited from A/c XX1234 on 10-03-26 to BUS. Avl bal:Rs.65,375', 'expectedAmount': 50.00, 'expectedDirection': 'debit', 'expectedRecipient': 'BUS', 'expectedRef': null},
  // 20. Movies
  {'body': 'Rs.800.00 spent on A/c XX1234 on 10-03-26 at PVR CINEMAS. Bal:Rs.64,575.00', 'expectedAmount': 800.00, 'expectedDirection': 'debit', 'expectedRecipient': 'PVR CINEMAS', 'expectedRef': null},
  // 21. Starbucks
  {'body': 'Rs.250.00 debited from A/c XX1234 on 10-03-26 to STARBUCKS via UPI Ref 421874651253. Avl bal:Rs.64,325.00', 'expectedAmount': 250.00, 'expectedDirection': 'debit', 'expectedRecipient': 'STARBUCKS', 'expectedRef': '421874651253'},
  // 22. Dividend
  {'body': 'Rs.10,000.00 credited to A/c XX1234 on 11-03-26 from DIVIDEND/TCS. Bal:Rs.74,325.00', 'expectedAmount': 10000.00, 'expectedDirection': 'credit', 'expectedRecipient': 'DIVIDEND/TCS', 'expectedRef': null},
  // 23. Parking
  {'body': 'Rs.45.00 debited from A/c XX1234 on 11-03-26 to PARKING via UPI Ref 521874651254. Avl bal:Rs.74,280.00', 'expectedAmount': 45.00, 'expectedDirection': 'debit', 'expectedRecipient': 'PARKING', 'expectedRef': '521874651254'},
  // 24. IKEA
  {'body': 'Rs.2000.00 spent on A/c XX1234 on 11-03-26 at IKEA. Bal:Rs.72,280.00', 'expectedAmount': 2000.00, 'expectedDirection': 'debit', 'expectedRecipient': 'IKEA', 'expectedRef': null},
  // 25. Bill
  {'body': 'Rs.1500.00 debited from A/c XX1234 on 12-03-26 to ELECTRICITY BOARD. Avl bal:Rs.70,780.00', 'expectedAmount': 1500.00, 'expectedDirection': 'debit', 'expectedRecipient': 'ELECTRICITY BOARD', 'expectedRef': null},
  // 26. Snacks
  {'body': 'Rs.85.00 debited from A/c XX1234 on 12-03-26 to SNACKS POINT via UPI Ref 621874651255. Avl bal:Rs.70,695.00', 'expectedAmount': 85.00, 'expectedDirection': 'debit', 'expectedRecipient': 'SNACKS POINT', 'expectedRef': '621874651255'},
  // 27. Internet
  {'body': 'Rs.500.00 debited from A/c XX1234 on 12-03-26 to INTERNET PROVIDER. Bal:Rs.70,195.00', 'expectedAmount': 500.00, 'expectedDirection': 'debit', 'expectedRecipient': 'INTERNET PROVIDER', 'expectedRef': null},
  // 28. Interest
  {'body': 'Rs.300.00 credited to A/c XX1234 on 13-03-26 from INTEREST C. Bal:Rs.70,495.00', 'expectedAmount': 300.00, 'expectedDirection': 'credit', 'expectedRecipient': 'INTEREST C', 'expectedRef': null},
  // 29. Pharmacy
  {'body': 'Rs.110.00 debited from A/c XX1234 on 13-03-26 to PHARMACY via UPI Ref 721874651256. Avl bal:Rs.70,385.00', 'expectedAmount': 110.00, 'expectedDirection': 'debit', 'expectedRecipient': 'PHARMACY', 'expectedRef': '721874651256'},
  // 30. Decathlon
  {'body': 'Rs.1000.00 spent on A/c XX1234 on 13-03-26 at DECATHLON SPORTS. Bal:Rs.69,385.00', 'expectedAmount': 1000.00, 'expectedDirection': 'debit', 'expectedRecipient': 'DECATHLON SPORTS', 'expectedRef': null},
  // 31. ATM again
  {'body': 'Rs.5000.00 withdrawn from A/c XX1234 at ATM on 14-03-26. Avl Bal:Rs.64,385.00', 'expectedAmount': 5000.00, 'expectedDirection': 'debit', 'expectedRecipient': 'ATM', 'expectedRef': null},
  // 32. Milk
  {'body': 'Rs.25.00 debited from A/c XX1234 on 14-03-26 to MILK DAIRY via UPI Ref 821874651257. Avl bal:Rs.64,360.00', 'expectedAmount': 25.00, 'expectedDirection': 'debit', 'expectedRecipient': 'MILK DAIRY', 'expectedRef': '821874651257'},
  // 33. Big Basket
  {'body': 'Rs.2500.00 spent on A/c XX1234 on 14-03-26 at BIG BASKET. Bal:Rs.61,860.00', 'expectedAmount': 2500.00, 'expectedDirection': 'debit', 'expectedRecipient': 'BIG BASKET', 'expectedRef': null},
  // 34. Auto
  {'body': 'Rs.50.00 debited from A/c XX1234 on 15-03-26 to RICKSHAW via UPI Ref 921874651258. Avl bal:Rs.61,810.00', 'expectedAmount': 50.00, 'expectedDirection': 'debit', 'expectedRecipient': 'RICKSHAW', 'expectedRef': '921874651258'},
  // 35. Uber
  {'body': 'Rs.450.00 debited from A/c XX1234 on 15-03-26 to UBER INDIA via UPI Ref 021874651259. Avl bal:Rs.61,360.00', 'expectedAmount': 450.00, 'expectedDirection': 'debit', 'expectedRecipient': 'UBER INDIA', 'expectedRef': '021874651259'},
  // 36. Taj
  {'body': 'Rs.1200.00 spent on A/c XX1234 on 15-03-26 at TAJ HOTELS. Bal:Rs.60,160.00', 'expectedAmount': 1200.00, 'expectedDirection': 'debit', 'expectedRecipient': 'TAJ HOTELS', 'expectedRef': null},
  // 37. Netflix
  {'body': 'Rs.500.00 debited from A/c XX1234 on 16-03-26 to NETFLIX ENT. Avl bal:Rs.59,660.00', 'expectedAmount': 500.00, 'expectedDirection': 'debit', 'expectedRecipient': 'NETFLIX ENT', 'expectedRef': null},
  // 38. Breakfast
  {'body': 'Rs.35.00 debited from A/c XX1234 on 16-03-26 to UDUPI CAFE via UPI Ref 121874651260. Avl bal:Rs.59,625.00', 'expectedAmount': 35.00, 'expectedDirection': 'debit', 'expectedRecipient': 'UDUPI CAFE', 'expectedRef': '121874651260'},
  // 39. Nike
  {'body': 'Rs.1500.00 spent on A/c XX1234 on 16-03-26 at NIKE STORE. Bal:Rs.58,125.00', 'expectedAmount': 1500.00, 'expectedDirection': 'debit', 'expectedRecipient': 'NIKE STORE', 'expectedRef': null},
  // 40. Friend
  {'body': 'Rs.100.00 credited to A/c XX1234 on 17-03-26 from FRIEND via UPI Ref 221874651261. Bal:Rs.58,225.00', 'expectedAmount': 100.00, 'expectedDirection': 'credit', 'expectedRecipient': 'FRIEND', 'expectedRef': '221874651261'},
  // 41. Zomato 2
  {'body': 'Rs.450.00 debited from A/c XX1234 on 17-03-26 to ZOMATO LMT via UPI Ref 321874651262. Avl bal:Rs.57,775.00', 'expectedAmount': 450.00, 'expectedDirection': 'debit', 'expectedRecipient': 'ZOMATO LMT', 'expectedRef': '321874651262'},
  // 42. Reliance Digital
  {'body': 'Rs.8000.00 spent on A/c XX1234 on 17-03-26 at RELIANCE DIGITAL. Bal:Rs.49,775.00', 'expectedAmount': 8000.00, 'expectedDirection': 'debit', 'expectedRecipient': 'RELIANCE DIGITAL', 'expectedRef': null},
  // 43. Tea
  {'body': 'Rs.20.00 debited from A/c XX1234 on 18-03-26 to TEA VENDOR via UPI Ref 421874651263. Avl bal:Rs.49,755.00', 'expectedAmount': 20.00, 'expectedDirection': 'debit', 'expectedRecipient': 'TEA VENDOR', 'expectedRef': '421874651263'},
  // 44. Gym
  {'body': 'Rs.1200.00 debited from A/c XX1234 on 18-03-26 to FITNESS FIRST. Bal:Rs.48,555.00', 'expectedAmount': 1200.00, 'expectedDirection': 'debit', 'expectedRecipient': 'FITNESS FIRST', 'expectedRef': null},
  // 45. Subway
  {'body': 'Rs.300.00 spent on A/c XX1234 on 18-03-26 at SUBWAY. Bal:Rs.48,255.00', 'expectedAmount': 300.00, 'expectedDirection': 'debit', 'expectedRecipient': 'SUBWAY', 'expectedRef': null},
  // 46. Deposit
  {'body': 'Rs.1500.00 credited to A/c XX1234 on 19-03-26 from CASH DEPOSIT MACH. Bal:Rs.49,755.00', 'expectedAmount': 1500.00, 'expectedDirection': 'credit', 'expectedRecipient': 'CASH DEPOSIT MACH', 'expectedRef': null},
  // 47. VPA Ref
  {'body': 'Rs.200.00 debited from a/c **1234 to VPA test@okaxis on 20-12-25. UPI Ref 500123456789. Bal: Rs. 15,200.34', 'expectedAmount': 200.00, 'expectedDirection': 'debit', 'expectedRecipient': 'test@okaxis', 'expectedRef': '500123456789'},
  // 48. Sent
  {'body': 'Rs.500.00 sent from A/c XX1234 to JOHN DOE on 21-12-25. Avl Bal: Rs. 14,700.34', 'expectedAmount': 500.00, 'expectedDirection': 'debit', 'expectedRecipient': 'JOHN DOE', 'expectedRef': null},
  // 49. Payment to
  {'body': 'Payment of Rs.100.00 to SWIGGY from A/c XX1234 on 22-12-25. Ref: 600123456789. Bal: Rs. 14,600.34', 'expectedAmount': 100.00, 'expectedDirection': 'debit', 'expectedRecipient': 'SWIGGY', 'expectedRef': '600123456789'},
  // 50. Received
  {'body': 'Received Rs.1,000.00 in A/c XX1234 from ALICE on 23-12-25. Ref: 700123456789. Bal: Rs. 15,600.34', 'expectedAmount': 1000.00, 'expectedDirection': 'credit', 'expectedRecipient': 'ALICE', 'expectedRef': '700123456789'},
];