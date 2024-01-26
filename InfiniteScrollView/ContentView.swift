//
//  ContentView.swift
//  InfiniteScrollView
//
//  Created by 王庭志 on 2024/1/18.
//

import SwiftUI

struct ContentView: View {
    
    @State private var manager = InfiniteScrollViewManager()
    
    var body: some View {
//        ZStack(alignment: .bottomTrailing) {
            InfiniteScrollView(manager: manager)
//            Button("back to") {
//                manager.backCenter()
//            }
//            .buttonStyle(.bordered)
//            .padding()
//        }
    }
}

struct InfiniteScrollView: UIViewRepresentable {
    typealias TileCoordinate = CGPoint
    var manager: InfiniteScrollViewManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        context.coordinator.setupScrollView(scrollView: scrollView)
        manager.coordinator = context.coordinator
        context.coordinator.manager = manager
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIScrollView, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        let size = CGSize(width: width, height: height)
        uiView.frame.size = size
        context.coordinator.resetOffset()
        return size
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var manager: InfiniteScrollViewManager!
        var scrollView: UIScrollView!
        let contentSize = CGSize(width: 100000, height: 100000)
        let tileSize = CGSize(width: 100, height: 100)
        
        // 用于记录 scrollView 的相对偏移量
        var offset: CGPoint = .zero
        // 记录
        var tiles: [TileCoordinate:UILabel] = [:]
        
        func setupScrollView(scrollView: UIScrollView) {
            self.scrollView = scrollView
            scrollView.delegate = self
            scrollView.scrollsToTop = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            resetOffset()
        }
        
        func resetOffset() {
            scrollView.contentSize = contentSize
            let offset = CGPoint(
                x: (scrollView.contentSize.width - scrollView.frame.size.width) / 2,
                y: (scrollView.contentSize.height - scrollView.frame.size.height) / 2
            )
            scrollView.setContentOffset(offset, animated: false)
            self.offset = .zero
        }
        
        func createTile(coordinate: TileCoordinate) {
            // 计算tile的origin
            let origin = CGPoint(
                x: (scrollView.contentSize.width - tileSize.width) / 2 + offset.x + coordinate.x * tileSize.width,
                y: (scrollView.contentSize.height - tileSize.height) / 2 + offset.y + coordinate.y * tileSize.height
            )
            
            // 设置基本属性
            let tile = UILabel(frame: CGRect(origin: origin, size: tileSize))
            tile.text = "(\(coordinate.x.formatted()), \(coordinate.y.formatted()))"
            tile.textAlignment = .center
            let isCenter = coordinate.equalTo(.zero)
            tile.backgroundColor = UIColor.gray.withAlphaComponent(isCenter ? 1 : 0.5)
            tile.layer.borderWidth = 0.5
            tile.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor
            // 加入渲染
            scrollView.addSubview(tile)
            // 加入记录
            tiles.updateValue(tile, forKey: coordinate)
        }
        
        // 处理绘制
        func renderTiles(rows: ClosedRange<Int>, cols: ClosedRange<Int>) {
            for row in rows {
                for col in cols {
                    if !tiles.keys.contains(TileCoordinate(x: col, y: row)) {
                        createTile(coordinate: TileCoordinate(x: col, y: row))
                    }
                }
            }
            removeTiles(rows: rows, cols: cols)
        }
        
        // 删除不在范围内的tile
        func removeTiles(rows: ClosedRange<Int>, cols: ClosedRange<Int>) {
            for coordinate in tiles.keys {
                if !rows.contains(Int(coordinate.y)) || !cols.contains(Int(coordinate.x)) {
                    let tile = tiles[coordinate]
                    tile?.removeFromSuperview()
                    tiles.removeValue(forKey: coordinate)
                    continue
                }
            }
        }
        
        // 计算需要渲染的tile
        func populateTiles() {
            let frame = scrollView.frame.size
            let left = Int(round((-frame.width / 2 - offset.x - deltaOffset.x) / tileSize.width))
            let right = Int(round((frame.width / 2 - offset.x - deltaOffset.x) / tileSize.width))
            let top = Int(round((-frame.height / 2 - offset.y - deltaOffset.y) / tileSize.height))
            let bottom = Int(round((frame.height / 2 - offset.y - deltaOffset.y) / tileSize.height))
            renderTiles(rows: top...bottom, cols: left...right)
        }
        
        var centerOffset: CGPoint {
            CGPoint(
                x: (scrollView.contentSize.width - scrollView.frame.size.width) / 2,
                y: (scrollView.contentSize.height - scrollView.frame.size.height) / 2
            )
        }
        func updateOffset() {
            if deltaOffset.equalTo(.zero) { return }
            offset = CGPoint(
                x: offset.x + deltaOffset.x,
                y: offset.y + deltaOffset.y
            )
            for tile in tiles {
                tile.value.frame.origin = CGPoint(
                    x: tile.value.frame.origin.x + deltaOffset.x,
                    y: tile.value.frame.origin.y + deltaOffset.y
                )
            }
            deltaOffset = .zero
            scrollView.setContentOffset(centerOffset, animated: false)
        }
        
        // MARK: Delegate methods
        var deltaOffset = CGPoint.zero
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            deltaOffset = CGPoint(
                x: (scrollView.contentSize.width - scrollView.frame.size.width) / 2 - scrollView.contentOffset.x,
                y: (scrollView.contentSize.height - scrollView.frame.size.height) / 2 - scrollView.contentOffset.y
            )
            populateTiles()
        }
        
        // 停止拖拽
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if (!decelerate) {
                updateOffset()
            }
        }
        
        // 停止减速（scroll停止）
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            updateOffset()
        }
        
        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            updateOffset()
        }
    }
}

@Observable
final class InfiniteScrollViewManager {
    weak var coordinator: InfiniteScrollView.Coordinator!
    
    func backCenter() {
        guard let coordinator, let scrollView = coordinator.scrollView else { return }
        scrollView.setContentOffset(CGPoint(
            x: (scrollView.contentSize.width - scrollView.frame.size.width) / 2 + coordinator.offset.x + coordinator.deltaOffset.x,
            y: (scrollView.contentSize.height - scrollView.frame.size.height) / 2 + coordinator.offset.y + coordinator.deltaOffset.y), animated: true)
    }
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

#Preview {
    ContentView()
}
