//
//  ProfileView.swift
//  BearFitness
//
//  Created by christine j on 4/10/26.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @AppStorage("profile_name")   private var name   = "Name"
    @AppStorage("profile_height") private var height = "5'6"
    @AppStorage("profile_weight") private var weight = "000"
    @AppStorage("profile_age")    private var age    = "21"

    @State private var editingName = false
    @State private var draftName   = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // MARK: - Name Header
                        HStack {
                            if editingName {
                                TextField("Name", text: $draftName, onCommit: {
                                    name = draftName
                                    editingName = false
                                })
                                .font(.system(size: 30, weight: .heavy))
                                .foregroundStyle(Color.appDarkText)
                                .tint(Color.gradientBlue)
                                .submitLabel(.done)

                                Button {
                                    name = draftName
                                    editingName = false
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.gradientBlue)
                                        .font(.system(size: 22))
                                }
                            } else {
                                Text(name)
                                    .font(.system(size: 30, weight: .heavy))
                                    .foregroundStyle(Color.appDarkText)

                                Spacer()

                                Button {
                                    draftName = name
                                    editingName = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.gray1)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // MARK: - Stats Row (Height / Weight / Age)
                        HStack(spacing: 12) {
                            statCard(value: height, label: "Height")
                            statCard(value: weight, label: "Weight")
                            statCard(value: age,    label: "Age")
                        }
                        .padding(.horizontal, 20)

                        // MARK: - Account Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Account")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.appDarkText)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 12)

                            // Heart Rate Zones
                            NavigationLink(destination: HeartRateZonesView()) {
                                HStack(spacing: 14) {
                                    Image(systemName: "heart")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.gradientBlue)
                                        .frame(width: 24, height: 24)

                                    Text("Heart Rate Zones")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.gray1)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.gray2)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .tint(.clear)

                            // Point History
                            NavigationLink(destination: PointHistoryView()) {
                                HStack(spacing: 14) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.gradientBlue)
                                        .frame(width: 24, height: 24)

                                    Text("Point History")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.gray1)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.gray2)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .tint(.clear)
                        }
                        .padding(.bottom, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .cardShadow()
                        .padding(.horizontal, 20)

                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Stat Card

    @ViewBuilder
    func statCard(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 25, weight: .medium))
                .gradientForeground(.blueLinear)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.gray1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow()
    }
}
