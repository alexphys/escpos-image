require_relative "base"

module EscposImage
  module ImageProcessors
    class MiniMagick < Base

      def initialize(image_or_path, options = {})
        require_mini_magick!

        @image = begin
          if image_or_path.is_a?(::MiniMagick::Image)
            image_or_path
          elsif image_or_path.is_a?(File)
             ::MiniMagick::Image.open(image_or_path.path)
          elsif image_or_path.is_a?(String)
            ::MiniMagick::Image.open(image_or_path)
          else
            raise InputNotSupported
          end
        end

        super
      end

      def get_pixel(x, y)
        @pixels ||= image.get_pixels

        r, g, b =
          @pixels[y][x][0],
          @pixels[y][x][1],
          @pixels[y][x][2]

        (r + b + g) / 3
      end

      def assert_options!
        assert_dimensions_multiple_of_8!
      end

      # MiniMagick gem is not required intentionally
      # This makes the gem more lightweight by making dependencies
      # optional and based on chosen image processor
      def require_mini_magick!
        return if defined?(::MiniMagick)
        require "mini_magick"
      rescue LoadError => e
        raise DependencyNotInstalled.new("mini_magick")
      end

      def process!
        if options.fetch(:compose_alpha, false)
          image.combine_options do |c|
            bg_r, bg_g, bg_b =
              options.fetch(:compose_alpha_bg_r, 255),
              options.fetch(:compose_alpha_bg_g, 255),
              options.fetch(:compose_alpha_bg_b, 255)
            c.background "rgb(#{bg_r},#{bg_g},#{bg_b})"
            c.flatten
          end
        end

        # Get the first image out of animated gifs
        image.collapse!

        # Optimise more actions to single call
        image.combine_options do |c|
          c.rotate options.fetch(:rotate) if options.has_key?(:rotate)
          c.resize options.fetch(:resize) if options.has_key?(:resize)

          c.grayscale('Rec709Luma') if options.fetch(:grayscale, false)

          if options.fetch(:dither, false)
            c.monochrome '+dither'
            # dither the image with FloydSteinberg algoritm for better results
            c.dither 'FloydSteinberg'
          end
        end

        # Limit the extent of the image to nice round numbers
        if options.fetch(:extent, false)
          image.extent "#{(image.width/8.0).round*8}x#{(image.height/8.0).round*8}"
        end
      end

    end
  end
end
