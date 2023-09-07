//
//  ViewController.swift
//  test
//
//  Created by Vivek Kumar on 07/09/23.
//

import Cocoa
import SwiftWhisper
import AudioKit

class ViewController: NSViewController {

	private var whisper: Whisper?
	@IBOutlet weak var button: NSButton!
	@IBOutlet var textView: NSTextView!
	
	private func convertAudioFileToPCMArray(fileURL: URL, completionHandler: @escaping (Result<[Float], Error>) -> Void) {
		var options = FormatConverter.Options()
		options.format = .wav
		options.sampleRate = 16000
		options.bitDepth = 16
		options.channels = 1
		options.isInterleaved = false

		let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
		let converter = FormatConverter(inputURL: fileURL, outputURL: tempURL, options: options)
		converter.start { error in
			if let error {
				completionHandler(.failure(error))
				return
			}

			let data = try! Data(contentsOf: tempURL) // Handle error here

			let floats = stride(from: 44, to: data.count, by: 2).map {
				return data[$0..<$0 + 2].withUnsafeBytes {
					let short = Int16(littleEndian: $0.load(as: Int16.self))
					return max(-1.0, min(Float(short) / 32767.0, 1.0))
				}
			}

			try? FileManager.default.removeItem(at: tempURL)

			completionHandler(.success(floats))
		}
	}
	
	private func toTimestamp(t: Int, comma: Bool = false) -> String {
		var msec = t * 10
		let hr = msec / (1000 * 60 * 60)
		msec = msec - hr * (1000 * 60 * 60)
		let min = msec / (1000 * 60)
		msec = msec - min * (1000 * 60)
		let sec = msec / 1000
		msec = msec - sec * 1000

		// ignore hour for now
		let timestamp = String(format: "%02d:%02d\(comma ? "," : ".")%03d", Int(min), Int(sec), Int(msec))
		
		return timestamp
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		let modelPath = Bundle.main.url(forResource: "ggml-tiny.en", withExtension: "bin", subdirectory: "models")
		var params = WhisperParams.init(strategy: .greedy)
		params.token_timestamps = true
		params.max_len = 1
		whisper = Whisper(fromFileURL: modelPath!, withParams: params)
	}
	
	private func transcriptionComplete(result: Result<[Segment], Error>) {
		switch result {
		case .success(let segments):
			for segment in segments {
				let t0 = toTimestamp(t: segment.startTime)
				let t1 = toTimestamp(t: segment.endTime)
				print("[\(t0) -> \(t1)] \(segment.text)")
				
				textView!.string += "[\(t0) -> \(t1)] \(segment.text)"
				textView!.string += "\n"
			}
					
		case .failure(let error):
			print("Error transcribing: \(error)")
		}
	}

	private func audioSampleCompletionHandler(result: Result<[Float], Error>) -> Void {
		switch result {
		case .success(let samples):
			whisper!.transcribe(audioFrames: samples, completionHandler: transcriptionComplete)
		case .failure(let error):
			print("Error converting audio: \(error)")
		}
	}
	
	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}

	@IBAction func transcribe(_ sender: Any) {
		let samplePath = Bundle.main.url(forResource: "jfk", withExtension: "wav", subdirectory: "samples")
		convertAudioFileToPCMArray(fileURL: samplePath!, completionHandler: audioSampleCompletionHandler)
	}
}

